// MarchingBlocks Paint for Unreal — THE TRANSITIONS BETWEEN THE LAYERS OF ONE WORLD: where two layers meet, the look of
// one is laid over the other's surface (the geometry never changes). The rule is MBCore's (MBTransitions, proven by
// Tests/transitions_conformance.json); the material (Content/Materials/M_MB_Transition) says it line by line, over the
// tiles' own materials, as their OVERLAY MATERIAL.
//
// The data travel in world.json ("transitions"): pairs of layers (a < b, layer indices in priority order) with how
// each covers the other, one representative look per layer (an image projected in a box, times a colour), and the
// vertices where a brush chose which layer covers. The world import makes this actor; editing its pairs relays them.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "MarchingBlocksLooks.h"
#include "MarchingBlocksTransitions.generated.h"

class AMarchingBlocksWorld;
class UMaterialInstanceDynamic;
class UTexture2D;
class UTexture2DArray;
class UVolumeTexture;

USTRUCT(BlueprintType)
struct MARCHINGBLOCKSPAINT_API FMarchingBlocksTransitionSettings
{
	GENERATED_BODY()

	/** How wide the blend is: 0.05 a sharp border, 1 a gradient over the whole band. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "0.05", ClampMax = "1.0"))
	float Softness = 0.45f;
	/** How far the covering layer reaches past the middle (negative: it draws back). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "-0.5", ClampMax = "0.5"))
	float Reach = 0.2f;
	/** How irregular the border is. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "0.0", ClampMax = "1.0"))
	float Irregularity = 0.35f;
	/** The size of that irregularity, per cell. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "0.25", ClampMax = "6.0"))
	float Grain = 1.5f;
	/** The covering layer fills the HOLLOWS of the covered one first (the dark of its image): sand in the cracks. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "0.0", ClampMax = "1.0"))
	float FillsHollows = 0.5f;
};

USTRUCT(BlueprintType)
struct MARCHINGBLOCKSPAINT_API FMarchingBlocksTransitionPair
{
	GENERATED_BODY()

	/** Layer indices in priority order (0 is the first layer), A < B. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	int32 A = 0;
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	int32 B = 1;
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	bool bActive = false;
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	FMarchingBlocksTransitionSettings ACoversB;
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	FMarchingBlocksTransitionSettings BCoversA;
};

/** A layer's look laid over the OTHER layer's surface: an image projected in a box (or a plain colour), times Color. */
USTRUCT(BlueprintType)
struct MARCHINGBLOCKSPAINT_API FMarchingBlocksRepresentative
{
	GENERATED_BODY()

	UPROPERTY()
	FMarchingBlocksImage Image;
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	bool bHasImage = false;
	/** Multiplies the image AS IS (no sRGB conversion of the colour). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	FLinearColor Color = FLinearColor::White;
	/** World cells per repeat of the image. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "0.01"))
	float Scale = 1.f;
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "0.0", ClampMax = "1.0"))
	float Roughness = 1.f;
};

UCLASS(ClassGroup = MarchingBlocks, meta = (DisplayName = "MarchingBlocks Transitions"))
class MARCHINGBLOCKSPAINT_API AMarchingBlocksTransitions : public AActor
{
	GENERATED_BODY()

public:
	AMarchingBlocksTransitions();

	/** The world whose layers blend (the layers' World Name). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	FName WorldName;

	/** Which layers blend, and how each covers the other. Layers 0 to 254 blend (two bytes per cell). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	TArray<FMarchingBlocksTransitionPair> Pairs;

	/** One per layer, in priority order. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	TArray<FMarchingBlocksRepresentative> Representatives;

	/** Where a brush chose which layer covers: x, y, z (a vertex, format space) and the layer index (W). */
	UPROPERTY()
	TArray<FIntVector4> Choices;

	/** Tints the blend where a vertex was chosen by the brush. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks")
	bool bShowChoices = false;

	UPROPERTY(VisibleAnywhere, Transient, Category = "MarchingBlocks")
	FString Status;

	/** The transitions actor of a world, or nullptr. */
	static AMarchingBlocksTransitions* Find(UWorld* World, FName InWorldName);

	/** Lays the blend over every tile of every layer of the world again (after a change of cells, layers or pairs). */
	UFUNCTION(CallInEditor, Category = "MarchingBlocks")
	void Apply();

	virtual void OnConstruction(const FTransform& Transform) override;
#if WITH_EDITOR
	virtual void PostEditChangeProperty(FPropertyChangedEvent& Event) override;
#endif

private:
	UPROPERTY(Transient)
	TObjectPtr<UVolumeTexture> CellsTexture;
	UPROPERTY(Transient)
	TObjectPtr<UTexture2D> TableTexture;
	UPROPERTY(Transient)
	TObjectPtr<UTexture2DArray> RepsTexture;
	UPROPERTY(Transient)
	TObjectPtr<UTexture2D> RepParamsTexture;
	UPROPERTY(Transient)
	TArray<TObjectPtr<UMaterialInstanceDynamic>> Mids;
};
