// MarchingBlocks Paint for Unreal — ONE WATER LAYER of a world: its sources, and the sheet MarchingBlocks baked
// (water/<name>.glb, its vertices in format space), drawn with a material — one of the six presets shipped with the
// plugin (stylized, clear, reflective, lava, swamp, acid), or any of yours.
//
// THE PRESETS ARE EXAMPLES, NOT A REQUIREMENT. Every vertex of the sheet carries the water data, and any water material
// can read them: COLOR_0 r, g = the flow along x and z (0.5 0.5 still); b = the kind (0 still, 0.5 river, 0.75 foam,
// 1 waterfall); a = the depth / 8 (still water, river) or the amount of foam (waterfall, foam); NORMAL the shape;
// TEXCOORD_0 x, z on flat water, across / height on a waterfall.
//
// The water CELLS are deduced again from the sources and the cells of every layer of the world (MBCore MBWater, proven
// by Tests/water_conformance.json): Recompute Water. The SHEET is not rebuilt (its rule has no reference cases yet):
// after painting, export from MarchingBlocks again for a new sheet.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "MBCore/MBRule.h"
#include "MarchingBlocksWater.generated.h"

class AMarchingBlocksWorld;
class UMaterialInterface;
class UStaticMesh;
class UStaticMeshComponent;

UCLASS(ClassGroup = MarchingBlocks, meta = (DisplayName = "MarchingBlocks Water"))
class MARCHINGBLOCKSPAINT_API AMarchingBlocksWater : public AActor
{
	GENERATED_BODY()

public:
	AMarchingBlocksWater();

	/** The world it flows in (the layers' World Name). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	FName WorldName;

	/** Its order among the world's water layers: the FIRST source in the void, in this order, is the sea. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	int32 Order = 0;

	/** "stylized", "clear", "reflective", "lava", "swamp", "acid" — a suggestion; the preset material it picks. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	FString Look = TEXT("clear");

	/** Where the water was placed, format space. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	TArray<FIntVector> Sources;

	/** The sheet MarchingBlocks baked (water/<name>.glb, imported with the same glTF importer as tiles.glb). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	TObjectPtr<UStaticMesh> Sheet;

	/** Your own water material; empty: the preset of Look. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	TObjectPtr<UMaterialInterface> Material;

	UPROPERTY(VisibleAnywhere, Transient, Category = "MarchingBlocks")
	FString Status;

	/** Deduces the water cells again from the sources of every water layer of the world and the cells of every layer. */
	UFUNCTION(CallInEditor, Category = "MarchingBlocks")
	void RecomputeWater();

	/** The water cells of this layer, as the last Recompute found them (format space). */
	const MBPaint::FCellSet& GetWaterCells() const { return WaterCells; }

	/** Every water cell of a world (all its water layers), deduced now. */
	static MBPaint::FCellSet WaterCellsOf(UWorld* World, FName InWorldName);

	virtual void OnConstruction(const FTransform& Transform) override;
#if WITH_EDITOR
	virtual void PostEditChangeProperty(FPropertyChangedEvent& Event) override;
#endif

private:
	void DrawSheet();

	UPROPERTY(Transient)
	TObjectPtr<UStaticMeshComponent> SheetComponent;

	MBPaint::FCellSet WaterCells;
};
