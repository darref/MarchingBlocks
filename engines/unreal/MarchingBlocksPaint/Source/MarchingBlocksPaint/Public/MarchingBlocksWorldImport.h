// MarchingBlocks Paint for Unreal — IMPORTS A PAINTED WORLD made by MarchingBlocks.
//
// A painted world is a `<name>.mbworld/` folder: world.json, and one `.mbset` tileset folder per tile
// source, inside it. Place this actor, set World File, press Import World: it makes one MarchingBlocks
// World actor per layer, in order, named after the layer, at this actor's transform, in the Outliner
// folder "MarchingBlocks/<world>". The whole import is ONE undo step; pressing it again replaces the
// layers it made before.
//
// Each tileset needs its tiles.glb imported (one Static Mesh per mesh, Combine Meshes OFF) into
// <Tiles Root>/<world>/<tileset>: the Status and the Output Log name every folder still missing.
// A layer without tiles keeps its cells and draws nothing — it is never given tiles it did not have.
//
// This actor is editor-only: it is not cooked, and nothing refers to it once the layers exist.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "MarchingBlocksWorldImport.generated.h"

class AMarchingBlocksWorld;

UCLASS(ClassGroup = MarchingBlocks, meta = (DisplayName = "MarchingBlocks World Import"))
class MARCHINGBLOCKSPAINT_API AMarchingBlocksWorldImport : public AActor
{
	GENERATED_BODY()

public:
	AMarchingBlocksWorldImport();

	/** The world.json inside a .mbworld folder made by MarchingBlocks. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (FilePathFilter = "json"))
	FFilePath WorldFile;

	/** The content folder the tiles are imported under: each tileset's tiles.glb goes into
	 *  <Tiles Root>/<world>/<tileset>. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ContentDir))
	FDirectoryPath TilesRoot;

	/** Size of one cell, in Unreal units (centimetres), given to every layer. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "1.0"))
	float CellSize = 100.f;

	/** Reads World File and makes one MarchingBlocks World per layer. One undo step; replaces the layers
	 *  a previous import made. A refused file changes nothing. */
	UFUNCTION(CallInEditor, Category = "MarchingBlocks")
	void ImportWorld();

	/** What the last import did, or why it refused the file. */
	UPROPERTY(VisibleAnywhere, Transient, Category = "MarchingBlocks")
	FString Status;

private:
	/** The layers the last import made, so that importing again replaces them. */
	UPROPERTY()
	TArray<TObjectPtr<AMarchingBlocksWorld>> Imported;
};
