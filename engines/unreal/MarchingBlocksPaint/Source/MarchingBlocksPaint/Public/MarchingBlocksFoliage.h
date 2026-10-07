// MarchingBlocks Paint for Unreal — THE FOLIAGE OF A WORLD: models (a .glb each, imported as a Static Mesh) and the
// plants placed on the world, swaying in the wind.
//
// The rule is MBCore's (MBFoliage, proven by Tests/foliage_conformance.json): where a model sits (on the point of the
// ground, turned by its yaw, scaled, raised by its ground offset), the three placing modes — in the air, planted with
// a free neighbourhood, planted overflowing — and their refusals, the brush, and the wind data of every plant
// (ground, height above it, phase, amplitude), which the wind material (Content/Materials/M_MB_Wind) reads per
// instance. Everything is in FORMAT space, converted through the frame of a layer of the same world.
//
// ⚠ The model's own animation (a skeleton) is not played — neither in MarchingBlocks nor in the plugins.
// ⚠ The wind needs the plugin's material: the imported materials are REPLACED by it on the plants, their textures and
//   factors copied (Interchange owns the imported ones).

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "MarchingBlocksFoliage.generated.h"

class AMarchingBlocksWorld;
class UHierarchicalInstancedStaticMeshComponent;
class UInstancedStaticMeshComponent;
class UMaterialInterface;
class UStaticMesh;

UENUM(BlueprintType)
enum class EMarchingBlocksFoliageMode : uint8
{
	/** In the air: on the grid plane; it only must not be inside the matter. */
	Air,
	/** Planted, free neighbourhood: on the ground, not too steep, not in water, its footprint carried by the ground,
	 *  nothing above it, no other plant on its footprint. */
	Free,
	/** Planted, overflowing: on the ground, not too steep, not in water — it may overflow an edge and its neighbours. */
	Overflow,
};

USTRUCT(BlueprintType)
struct MARCHINGBLOCKSPAINT_API FMarchingBlocksFoliageModel
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	int32 Id = 0;
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	FString Name;
	/** The .glb in the exported world (relative to world.json), for the record. */
	UPROPERTY(VisibleAnywhere, Category = "MarchingBlocks")
	FString MeshFile;
	/** The imported model (same glTF importer as tiles.glb, so the same frame). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	TObjectPtr<UStaticMesh> Mesh;
	/** Model units: how far its origin sits ABOVE the ground (negative buries it). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	float GroundOffset = 0.f;
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "0.01"))
	float Scale = 1.f;
	/** Each plant draws a factor in [1 - a, 1 + a]. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "0.0", ClampMax = "0.9"))
	float ScaleRandom = 0.2f;
	/** The footprint radius on the ground, in cells, at scale 1. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "0.0"))
	float Footprint = 0.5f;
	/** The top of the model above its origin, model units. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	float Height = 1.f;
	/** 0 still to 1. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "0.0", ClampMax = "1.0"))
	float Wind = 0.5f;
};

USTRUCT(BlueprintType)
struct MARCHINGBLOCKSPAINT_API FMarchingBlocksPlant
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	int32 Model = 0;
	/** The point ON THE GROUND, format space. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	FVector Point = FVector::ZeroVector;
	/** Radians around format +Y. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	float Yaw = 0.f;
	/** The plant's own draw (the model has its own scale). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	float Scale = 1.f;
	/** Planted (on the ground) or placed in the air. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	bool bPlanted = true;
};

UCLASS(ClassGroup = MarchingBlocks, meta = (DisplayName = "MarchingBlocks Foliage"))
class MARCHINGBLOCKSPAINT_API AMarchingBlocksFoliage : public AActor
{
	GENERATED_BODY()

public:
	AMarchingBlocksFoliage();

	/** The world it grows on (the layers' World Name): their frame converts it, their cells carry it. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	FName WorldName;

	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	TArray<FMarchingBlocksFoliageModel> Models;

	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	TArray<FMarchingBlocksPlant> Plants;

	// ── Planting (the Foliage tool of the MarchingBlocks mode) ──

	/** The model a click or a stroke plants (its Id). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Planting")
	int32 CurrentModel = 0;
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Planting")
	EMarchingBlocksFoliageMode Mode = EMarchingBlocksFoliageMode::Free;
	/** The least distance between two plants, whatever the mode, in cells. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Planting", meta = (ClampMin = "0.0"))
	float Spacing = 0.f;
	/** The steepest ground a plant takes, in degrees. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Planting", meta = (ClampMin = "0.0", ClampMax = "90.0"))
	float MaxSlope = 40.f;
	/** The brush: its radius in cells, and how many points it tries per dab. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Planting", meta = (ClampMin = "0.5", ClampMax = "32.0"))
	float BrushRadius = 3.f;
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Planting", meta = (ClampMin = "1", ClampMax = "200"))
	int32 BrushTries = 12;
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Planting")
	bool bRandomYaw = true;

	UPROPERTY(VisibleAnywhere, Transient, Category = "MarchingBlocks")
	FString Status;

	/** The foliage actor of a world, or nullptr. */
	static AMarchingBlocksFoliage* Find(UWorld* World, FName InWorldName);

	/** Draws every plant again (after a change of models or plants). */
	UFUNCTION(CallInEditor, Category = "MarchingBlocks")
	void Rebuild();

	/** One plant at a point of the world: the ground under it (planted modes), the rule, then added — as one undo step.
	 *  Returns the refusal ("" when planted). */
	FString PlantAt(const FVector& WorldOrigin, const FVector& WorldDirection);
	/** A dab of the brush around the point the ray meets: BrushTries random points in the disc, each placed on the
	 *  ground and checked; accepted plants respect each other. One undo step. Returns how many were planted. */
	int32 SowAt(const FVector& WorldOrigin, const FVector& WorldDirection);
	/** Removes the plants within BrushRadius of the point the ray meets. */
	int32 EraseAt(const FVector& WorldOrigin, const FVector& WorldDirection);
	/** The first layer of the world, whose frame converts the plants. */
	AMarchingBlocksWorld* FrameLayer() const;

	virtual void OnConstruction(const FTransform& Transform) override;
#if WITH_EDITOR
	virtual void PostEditChangeProperty(FPropertyChangedEvent& Event) override;
	virtual void PostEditUndo() override;
#endif

private:
	/** Where a world ray meets the world: the matter (the tiles, then the cells), in format space. False: nowhere. */
	bool AimedPoint(const FVector& WorldOrigin, const FVector& WorldDirection, FVector& OutFormat) const;

	UPROPERTY(Transient)
	TArray<TObjectPtr<UInstancedStaticMeshComponent>> Generated;
	UPROPERTY(Transient)
	TMap<TObjectPtr<UMaterialInterface>, TObjectPtr<UMaterialInterface>> WindLooks;
	uint32 Draws = 1;
};
