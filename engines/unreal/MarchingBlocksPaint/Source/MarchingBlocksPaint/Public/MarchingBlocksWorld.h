// MarchingBlocks Paint for Unreal — ONE WORLD LAYER: you paint cells, the tiles follow.
//
// Cells are stored in FORMAT space (the tileset's own grid: right-handed, +Y up). What you see is
// converted through the FRAME measured on the tileset's marker, so cells and tiles always agree, whatever
// your glTF importer did (Unreal is left-handed, +Z up, in centimetres).
//
// One actor is one LAYER, with its own tileset. Actors with the same World Name are the layers of ONE
// world (rock, ice…), in Priority order (the lowest first, the highest priority). The rule reads every
// visible layer together — no wall where two layers meet — and a vertex is placed by the highest layer among
// its 8 cells, with that layer's tiles. A cell belongs to one layer: Apply removes the cells it sets from the
// other layers. A hidden layer leaves the world. An empty World Name keeps the actor alone. The generated
// tile components are transient: a level only stores the cells, the manifest and the measured frame.
//
// The editing tools live in the "MarchingBlocks" editor mode (the MarchingBlocksPaintEditor module);
// their settings and the selection operations are here, in the Details panel.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "MBCore/MBFrame.h"
#include "MBCore/MBRule.h"
#include "MBCore/MBShapes.h"
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
	/** DEPRECATED — Navigate is no longer an aim but a switch (bNavigate, Space). Kept, hidden, only so a
	 *  level saved with it still loads: it is read back as Grid + navigating (PostLoad). Never set it. */
	Navigate UMETA(Hidden),
};

UENUM(BlueprintType)
enum class EMarchingBlocksTool : uint8
{
	Add, Dig, Select,
	/** A FLAT rectangle on the floor, whatever the aim — the floor of a room. */
	Rect,
	/** A 3D box: the whole volume, empty cells included. */
	Box,
	/** A special shape — tunnel, well, bridge, balcony or stairs (Special Shape below). Always aimed at the matter. */
	Shape,
};

UENUM(BlueprintType)
enum class EMarchingBlocksSpecialShape : uint8
{
	/** Digs into a WALL, square to it: one click goes through to the next cave (or Shape Length deep). */
	Tunnel,
	/** Digs into a FLOOR or a CEILING, straight: one click stops in the cave below (or Shape Length deep). */
	Well,
	/** A deck out of a WALL across the air, to the first wall in front (within Shape Length). */
	Bridge,
	/** A slab sticking out of a WALL at the height you click, with its rail. */
	Balcony,
	/** Stairs against a WALL: click where they should arrive, they come down to the ground (Stairs Step cells per
	 *  step). Connect: from one FLOOR to another, higher up. */
	Stairs,
};

UENUM(BlueprintType)
enum class EMarchingBlocksShapeProfile : uint8
{
	Round,
	Square,
	/** A flat floor and a round vault: a corridor you can walk. */
	Arch,
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

	/** The world this layer belongs to: actors with the same name are layers of ONE world. Empty: alone. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Layers")
	FName WorldName;

	/** Where layers meet, the layer with the LOWEST priority places the tiles (the world import numbers them
	 *  in the order MarchingBlocks gave: 0 is the top of its list). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Layers")
	int32 Priority = 0;

	/** The floor the Grid aim paints on, in cells. Page Up / Page Down in the MarchingBlocks mode. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Tools")
	int32 Floor = 0;

	/** Tab alternates Grid and Sculpt. Choosing an aim leaves navigation. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Tools")
	EMarchingBlocksAim Aim = EMarchingBlocksAim::Grid;

	/** Space: no click paints, the mouse and keys fly the viewport as usual (right drag + W A S D, Q E).
	 *  The aim is kept, and comes back unchanged when you switch it off. Not saved with the level. */
	UPROPERTY(EditAnywhere, Transient, Category = "MarchingBlocks|Tools", meta = (DisplayName = "Navigate (Space)"))
	bool bNavigate = false;

	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Tools")
	EMarchingBlocksTool Tool = EMarchingBlocksTool::Add;

	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Tools", meta = (ClampMin = "1", ClampMax = "7"))
	int32 BrushSize = 1;

	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Tools")
	EMarchingBlocksBrushShape BrushShape = EMarchingBlocksBrushShape::Sphere;

	/** Box only: keeps the skin of the box — a room. A box thinner than three cells stays solid. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Tools")
	bool bHollowBox = false;

	/** The shape the Shape tool makes. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Special shapes")
	EMarchingBlocksSpecialShape SpecialShape = EMarchingBlocksSpecialShape::Tunnel;

	/** Off: one click, straight out of the face. On: two clicks on two faces anywhere — slanted walls included —
	 *  joined with both ends open (Esc forgets the first); two floors for stairs. Not for the balcony. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Special shapes", meta = (DisplayName = "Connect two faces"))
	bool bConnectEnds = false;

	/** Tunnel and well. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Special shapes")
	EMarchingBlocksShapeProfile ShapeProfile = EMarchingBlocksShapeProfile::Round;

	/** 1 is one cell across, 2 is three, 3 is five… ( [ and ] with the Shape tool). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Special shapes", meta = (ClampMin = "1", ClampMax = "7"))
	int32 ShapeSize = 2;

	/** One click: how deep a tunnel or well goes when it finds no cave, how far a bridge looks for a wall, how
	 *  far a balcony sticks out, how far stairs may run before they reach the ground. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Special shapes", meta = (ClampMin = "1", ClampMax = "64"))
	int32 ShapeLength = 8;

	/** One-click stairs: how deep each step is, in cells (1 is steep). */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Special shapes", meta = (ClampMin = "1", ClampMax = "4"))
	int32 StairsStep = 2;

	/** Bridge, balcony and stairs: a one-cell rim along the open sides. Needs a Shape Size of 2 or more. */
	UPROPERTY(EditAnywhere, Category = "MarchingBlocks|Special shapes", meta = (DisplayName = "Rail"))
	bool bShapeRail = true;

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

	/** The aim and the navigation switch as MBCore sees them (a legacy Navigate aim reads as Grid + navigating). */
	MBPaint::FAimState GetAimState() const;
	void SetAimState(const MBPaint::FAimState& State);

	const MBPaint::FCellSet& GetCells();
	/** The layers of this actor's world, in priority order (itself included; just itself without a World Name). */
	TArray<AMarchingBlocksWorld*> GetLayers() const;
	/** Rebuilds every layer of the world: a change of cells moves the borders of the others. */
	void RebuildWorld();
	/** Is this layer in its world's union? (Not when hidden — in the editor viewport, or in game.) */
	bool IsLayerVisible() const;
	/** Applies what a tool returned: clears, then sets, then rebuilds the world once. Call Modify() first to
	 *  undo; the other layers it takes cells from are Modify()'d here, in the same transaction. */
	int32 Apply(const MBPaint::FChange& Change);
	/** Runs a selection operation as one undo step; the floor follows an extrusion. */
	int32 Operate(MBPaint::ESelectionOp Op, const TCHAR* UndoName);
	/** Moves the selected matter by Offset (format space), as one undo step. */
	void MoveSelection(const MBPaint::FCell& Offset);
	/** The special shape's settings as MBCore reads them; the ends (A, B) are the caller's. */
	MBPaint::FShapeRequest ShapeSettings() const;

	/** Sets the whole layer at once — its tile source and its cells (format space) — then rebuilds. Used by
	 *  the world import. An empty TilesetFile is a layer WITHOUT tiles: its cells are kept, nothing is drawn,
	 *  and the Status says so. Call Modify() first to undo. */
	void SetLayer(const FString& TilesetFile, const FString& InTilesFolder, const std::vector<MBPaint::FCell>& InCells);
	/** True once the frame marker 'mb_frame' was found in the Tiles Folder, i.e. tiles.glb is imported there. */
	bool HasTileMeshes() const;

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
	virtual void PostLoad() override;
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
