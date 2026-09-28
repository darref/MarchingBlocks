// MarchingBlocks Paint for Unreal — ONE WORLD LAYER: you paint cells, the tiles follow.
//
// Cells are stored in FORMAT space (the tileset's own grid: right-handed, +Y up). What you see is
// converted through the FRAME measured on the tileset's marker, so cells and tiles always agree, whatever
// your glTF importer did (Unreal is left-handed, +Z up, in centimetres).
//
// One actor is one layer: its tiles only ever look at its own cells. The generated tile components are
// transient: a level only stores the cells, the manifest and the measured frame, and rebuilds the rest.
//
// The editing tools live in the "MarchingBlocks" editor mode (the MarchingBlocksPaintEditor module);
// their settings and the selection operations are here, in the Details panel.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "MBCore/MBFrame.h"
#include "MBCore/MBRule.h"
#include "MBCore/MBTools.h"
#include "MarchingBlocksWorld.generated.h"

class UInstancedStaticMeshComponent;
class UStaticMesh;

UENUM(BlueprintType)
enum class EMarchingBlocksAim : uint8
{
	/** Aims at the floor plane (Page Up / Page Down move it). */
	Grid,
	/** Aims at the matter itself; falls back on the floor when the ray meets nothing. */
	Sculpt,
	/** Aims at nothing: the viewport flies as usual (right drag + W A S D, Q E). No click paints. */
	Navigate,
};

UENUM(BlueprintType)
enum class EMarchingBlocksTool : uint8
{
	Add, Dig, Select,
	/** A FLAT rectangle on the floor, whatever the aim — the floor of a room. */
	Rect,
	/** A 3D box: the whole volume, empty cells included. */
	Box,
};

UENUM(BlueprintType)
enum class EMarchingBlocksBrushShape : uint8 { Sphere, Cube, Disc };

UCLASS(ClassGroup = MarchingBlocks, meta = (DisplayName = "MarchingBlocks World"))
class MARCHINGBLOCKSPAINT_API AMarchingBlocksWorld : public AActor
{
	GENERATED_BODY()

public:
	AMarchingBlocksWorld();

	/** The tileset.json inside a .mbset folder made by MarchingBlocks. Read when you set it; the level
	 *  keeps a copy, so a packaged game does not need the file. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (FilePathFilter = "json"))
	FFilePath Tileset;

	/** The content folder where tiles.glb was imported (one Static Mesh per tile, "Combine Meshes" OFF). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ContentDir))
	FDirectoryPath TilesFolder;

	/** Size of one cell, in Unreal units (centimetres). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks", meta = (ClampMin = "1.0"))
	float CellSize = 100.f;

	/** The floor the Grid aim paints on, in cells. Page Up / Page Down in the MarchingBlocks mode. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Tools")
	int32 Floor = 0;

	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Tools")
	EMarchingBlocksAim Aim = EMarchingBlocksAim::Grid;

	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Tools")
	EMarchingBlocksTool Tool = EMarchingBlocksTool::Add;

	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Tools", meta = (ClampMin = "1", ClampMax = "7"))
	int32 BrushSize = 1;

	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Tools")
	EMarchingBlocksBrushShape BrushShape = EMarchingBlocksBrushShape::Sphere;

	/** Box only: keeps the skin of the box — a room. A box thinner than three cells stays solid. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Tools")
	bool bHollowBox = false;

	// ── The selection operations: buttons in the Details panel. Each one is one undo step. ──

	UFUNCTION(CallInEditor, Category = "MarchingBlocks|Selection") void Fill();
	UFUNCTION(CallInEditor, Category = "MarchingBlocks|Selection") void DeleteSelected();
	UFUNCTION(CallInEditor, Category = "MarchingBlocks|Selection") void ExtrudeUp();
	UFUNCTION(CallInEditor, Category = "MarchingBlocks|Selection") void ExtrudeDown();
	UFUNCTION(CallInEditor, Category = "MarchingBlocks|Selection") void Grow();
	UFUNCTION(CallInEditor, Category = "MarchingBlocks|Selection") void Shrink();
	UFUNCTION(CallInEditor, Category = "MarchingBlocks|Selection") void SelectConnected();
	UFUNCTION(CallInEditor, Category = "MarchingBlocks|Selection") void ClearSelection();
	UFUNCTION(CallInEditor, Category = "MarchingBlocks|Selection") void CopySelection();
	UFUNCTION(CallInEditor, Category = "MarchingBlocks|Selection") void CutSelection();
	/** Then click in the viewport, in the MarchingBlocks mode (Esc cancels). */
	UFUNCTION(CallInEditor, Category = "MarchingBlocks|Selection") void PasteClipboard();
	UFUNCTION(CallInEditor, Category = "MarchingBlocks") void Rebuild();
	UFUNCTION(CallInEditor, Category = "MarchingBlocks") void ClearCells();

	// ── For the editor mode and for code ──

	const MBPaint::FCellSet& GetCells();
	/** Applies what a tool returned: clears, then sets, then rebuilds once. Call Modify() first to undo. */
	int32 Apply(const MBPaint::FChange& Change);
	/** Runs a selection operation as one undo step; the floor follows an extrusion. */
	int32 Operate(MBPaint::ESelectionOp Op, const TCHAR* UndoName);
	/** Moves the selected matter by Offset (format space), as one undo step. */
	void MoveSelection(const MBPaint::FCell& Offset);

	/** The ray against the MATTER (the cells, never the rendered tiles), converted into format space. */
	MBPaint::FHit RayAgainstCells(const FVector& WorldOrigin, const FVector& WorldDirection,
		const MBPaint::FCellSet* Ignore = nullptr);
	/** The cell of the current floor under a world ray. */
	bool CellUnderRay(const FVector& WorldOrigin, const FVector& WorldDirection, MBPaint::FCell& OutCell);
	/** World transform of the unit cube of a cell (mirror included) — for drawing. */
	FMatrix CellMatrix(const MBPaint::FCell& Cell);
	/** A world direction in format space, and back. */
	FVector WorldDirectionToFormat(const FVector& Direction);

	MBPaint::FCellSet Selection;
	std::vector<MBPaint::FCell> Clipboard;
	bool bPasting = false;
	/** What went wrong last, for the Details panel and the viewport. */
	UPROPERTY(VisibleAnywhere, Transient, Category = "MarchingBlocks")
	FString Status;

	virtual void OnConstruction(const FTransform& Transform) override;
#if WITH_EDITOR
	virtual void PostEditChangeProperty(FPropertyChangedEvent& Event) override;
	virtual void PostEditUndo() override;
#endif

private:
	/** The cells, in format space. The ONLY saved truth; the set below is an index of it. */
	UPROPERTY()
	TArray<FIntVector> Cells;

	/** A copy of tileset.json, so the level rebuilds without the file. */
	UPROPERTY()
	FString ManifestText;

	/** The measured frame: images of the format axes, in the imported meshes' space (units included). */
	UPROPERTY()
	FVector FrameX = FVector(1, 0, 0);
	UPROPERTY()
	FVector FrameY = FVector(0, 1, 0);
	UPROPERTY()
	FVector FrameZ = FVector(0, 0, 1);
	UPROPERTY()
	float FrameUnit = 1.f;

	UPROPERTY(Transient)
	TArray<TObjectPtr<UInstancedStaticMeshComponent>> Generated;

	/** Tile name → its imported Static Mesh. Saved, so a packaged game references the meshes it needs. */
	UPROPERTY()
	TMap<FString, TObjectPtr<UStaticMesh>> TileMeshes;

	MBPaint::FCellSet Index;
	bool bIndexValid = false;
	TUniquePtr<MBPaint::FRule> Rule;

	void LoadTileset();
	void FindTileMeshes();
	bool MeasureFrame(UStaticMesh* Marker);
	MBPaint::FFrame Frame() const;
	FVector FormatToLocal(const FVector& P) const;
	FVector LocalToFormat(const FVector& P) const;
	void RunTransacted(const TCHAR* Name, TFunctionRef<void()> Body);
};
