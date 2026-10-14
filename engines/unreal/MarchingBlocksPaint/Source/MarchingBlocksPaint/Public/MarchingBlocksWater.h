// MarchingBlocks Paint for Unreal — ONE WATER LAYER of a world: its sources, and its SHEET — the one MarchingBlocks baked
// (water/<name>.glb, its vertices in format space), then the one REBUILT here when you paint — drawn with a material:
// one of the six presets shipped with the plugin (stylized, clear, reflective, lava, swamp, acid), or any of yours.
//
// THE PRESETS ARE EXAMPLES, NOT A REQUIREMENT. Every vertex of the sheet carries the water data, and any water material
// can read them: COLOR_0 r, g = the flow along x and z (0.5 0.5 still); b = the kind (0 still, 0.5 river, 0.75 foam,
// 1 waterfall); a = the depth / 8 (still water, river) or the amount of foam (waterfall, foam); NORMAL the shape;
// TEXCOORD_0 x, z on flat water, across / height on a waterfall.
//
// THE WATER FOLLOWS THE WORLD. The water cells AND the sheet are deduced again from the sources of every water layer
// and the cells of every layer (MBCore: MBWater, proven by Tests/water_conformance.json; MBWaterMesh, proven by
// Tests/water_mesh_conformance.json — the same sheet as MarchingBlocks bakes):
//   - never DURING a gesture: while you paint, the sheet you see is the last one (it says it is stale);
//   - about half a second after the last gesture (a stroke released, an undo, a redo), on a worker thread, resumed
//     like MarchingBlocks does it (only the sources whose reach a gesture touched are computed again), then swapped
//     in on the game thread;
//   - when one automatic rebuild took more than about a second, the automatic follow switches itself off (the sheet
//     stays stale): press Rebuild Water — always there, here and in the MarchingBlocks mode panel.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "MBCore/MBRule.h"
#include "MBCore/MBWaterMesh.h"
#include "MarchingBlocksWater.generated.h"

class AMarchingBlocksWorld;
class UMaterialInterface;
class UStaticMesh;
class UStaticMeshComponent;

/** Where the ground of the tiles is drawn, for the heights of the water (world.json "water_floor"): the top of a full cell
 *  y - 1 is seen at y - 0.25 (inset), y (centred) or y + 0.25 (outset). */
UENUM()
enum class EMarchingBlocksWaterFloor : uint8
{
	Inset,
	Centred,
	Outset
};

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

	/** The floor the water sits on (world.json "water_floor", set at import): lakes at L + 1 - |r| - 0.05, rivers at
	 *  y + 0.3 - r (r = 0.25 inset, 0 centred, -0.25 outset). The FIRST water layer of the world (lowest Order) decides
	 *  for all of them. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	EMarchingBlocksWaterFloor WaterFloor = EMarchingBlocksWaterFloor::Inset;

	/** The floor r of WaterFloor: 0.25, 0 or -0.25. */
	double FloorValue() const;

	/** The floor value of world.json (0.25, 0, -0.25) as the enum. */
	static EMarchingBlocksWaterFloor FloorFromValue(double R);

	/** The sheet MarchingBlocks baked (water/<name>.glb, imported with the same glTF importer as tiles.glb). Shown until
	 *  the water is rebuilt here. */
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

	/** REBUILD WATER: the cells and the sheet of every water layer of this world, now (on a worker thread), and the
	 *  automatic follow back on if it takes less than about a second. */
	UFUNCTION(CallInEditor, Category = "MarchingBlocks")
	void RebuildWater();

	/** Compares the sheet rebuilt here with the baked one (Sheet) — they must be the same triangles, colours to 1/255. */
	UFUNCTION(CallInEditor, Category = "MarchingBlocks")
	void CompareWithBakedSheet();

	/** The water cells of this layer, as the last Recompute or Rebuild found them (format space). */
	const MBPaint::FCellSet& GetWaterCells() const { return WaterCells; }

	/** True once the sheet shown is the one rebuilt here (not the baked one). */
	bool IsShowingRebuiltSheet() const { return bRebuilt; }

	/** The sheet rebuilt here (empty until a rebuild), format space. */
	const MBPaint::FWaterMesh& GetRebuiltSheet() const { return RebuiltData; }

	/** Every water cell of a world (all its water layers), deduced now. */
	static MBPaint::FCellSet WaterCellsOf(UWorld* World, FName InWorldName);

	// ── The follow (called by the world's layers and the MarchingBlocks mode) ──

	/** The cells of a world changed (a gesture, an undo, a redo): its water is stale, rebuilt ~0.5 s after the last one. */
	static void NoteWorldEdited(UWorld* World, FName InWorldName);
	/** A gesture is open (a stroke or a box held): no rebuild starts until it is closed. */
	static void SetGestureOpen(bool bOpen);
	/** Rebuild Water for a whole world, now. False when the world has no water layer. */
	static bool RebuildWorldWater(UWorld* World, FName InWorldName);
	/** What the follow of a world says (stale, rebuilding, the last time, automatic or not); empty without water. */
	static FString FollowStatus(UWorld* World, FName InWorldName);
	/** True while a rebuild runs or waits for the end of a gesture. */
	static bool IsRebuildPending(UWorld* World, FName InWorldName);

	virtual void OnConstruction(const FTransform& Transform) override;
#if WITH_EDITOR
	virtual void PostEditChangeProperty(FPropertyChangedEvent& Event) override;
	virtual void PostEditUndo() override;
#endif

	/** Called on the game thread with this layer's rebuilt sheet and water cells. */
	void ShowRebuiltSheet(MBPaint::FWaterMesh&& Mesh, MBPaint::FCellSet&& Cells, const FString& Said);

private:
	void DrawSheet();
	void DrawRebuilt();
	UMaterialInterface* ChosenMaterial(class UMaterialInstanceDynamic*& OutMid);

	UPROPERTY(Transient)
	TObjectPtr<UStaticMeshComponent> SheetComponent;

	UPROPERTY(Transient)
	TObjectPtr<UStaticMesh> RebuiltSheet;

	UPROPERTY(Transient)
	TObjectPtr<UStaticMeshComponent> RebuiltComponent;

	MBPaint::FCellSet WaterCells;
	MBPaint::FWaterMesh RebuiltData;
	/** The sheet shown is the rebuilt one (RebuiltSheet is null when it has no triangle: the water is gone). */
	bool bRebuilt = false;
};
