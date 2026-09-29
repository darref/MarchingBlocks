// MarchingBlocks Paint for Unreal — THE WORLD EDITING TOOLS, in the level viewport.
//
// Select a MarchingBlocks World actor, then pick "MarchingBlocks" in the Modes menu. The rules live in
// MBCore/MBTools (standard C++, proven by tools_conformance.json); this mode only aims, previews and
// applies inside an undo transaction. Its settings and the selection operations are on the actor, in the
// Details panel.
//
//   AIM      Grid — the floor plane (Page Up / Page Down) · Sculpt — the matter itself
//            Navigate — aims at nothing: the viewport flies as usual. Tab cycles the three.
//   TOOLS    Add (A) · Dig (D) · Select (S) · Rect (G) · Box (B)     Shift does the opposite
//   BRUSH    size 1–7 ([ and ]); shape and Hollow on the actor
//   KEYS     Delete · Esc · arrows move the selection (they follow the camera; Shift + up / down lift)
//            Ctrl+C / Ctrl+X / Ctrl+V copy, cut, paste
//
// The right mouse button and W A S D Q E are never taken: flying the viewport works in every aim.

#pragma once

#include "CoreMinimal.h"
#include "Tools/UEdMode.h"
#include "Tools/LegacyEdModeInterfaces.h"
#include "MBCore/MBTools.h"
#include "MarchingBlocksEdMode.generated.h"

class AMarchingBlocksWorld;

// ⚠ THE VIEWPORT AND DRAW INTERFACES ARE INHERITED EXPLICITLY. Measured on Unreal 5.8: UEdMode itself no
// longer declares InputKey, MouseMove or Render — the mode manager casts every mode to
// ILegacyEdModeViewportInterface (mouse, keys) and ILegacyEdModeDrawHelperInterface (Draw) instead.
UCLASS()
class UMarchingBlocksEdMode : public UEdMode, public ILegacyEdModeViewportInterface,
	public ILegacyEdModeDrawHelperInterface
{
	GENERATED_BODY()

public:
	static const FEditorModeID ModeId;

	UMarchingBlocksEdMode();

	virtual void Exit() override;
	virtual bool UsesToolkits() const override { return false; }
	virtual bool InputKey(FEditorViewportClient* ViewportClient, FViewport* Viewport, FKey Key, EInputEvent Event) override;
	virtual bool MouseMove(FEditorViewportClient* ViewportClient, FViewport* Viewport, int32 X, int32 Y) override;
	virtual bool CapturedMouseMove(FEditorViewportClient* ViewportClient, FViewport* Viewport, int32 X, int32 Y) override;
	virtual void Draw(const FSceneView* View, FPrimitiveDrawInterface* PDI) override;
	virtual bool IsSelectionAllowed(AActor* InActor, bool bInSelection) const override { return true; }

private:
	AMarchingBlocksWorld* Target() const;
	bool MouseRay(FEditorViewportClient* ViewportClient, FViewport* Viewport, FVector& Origin, FVector& Direction) const;
	bool Aimed(AMarchingBlocksWorld* World, const FVector& Origin, const FVector& Direction, bool bAdd, MBPaint::FHit& Hit);
	bool BoxCorner(AMarchingBlocksWorld* World, const FVector& Origin, const FVector& Direction, MBPaint::FCell& Corner);
	void Hover(FEditorViewportClient* ViewportClient, FViewport* Viewport);
	void Touch(AMarchingBlocksWorld* World, MBPaint::EBrushTool BrushTool, const MBPaint::FCell& Anchor,
		const MBPaint::FHit& Hit, const std::vector<MBPaint::FCell>& Cells, bool bDeselect);
	bool HandleShortcut(AMarchingBlocksWorld* World, FViewport* Viewport, FKey Key);
	MBPaint::FCell ArrowOffset(AMarchingBlocksWorld* World, FEditorViewportClient* ViewportClient, FKey Key, bool bShift) const;
	MBPaint::EBrushTool Gesture(const AMarchingBlocksWorld* World, bool bInverse) const;

	// The current stroke.
	bool bStroking = false;
	bool bStrokeInverse = false;
	bool bStrokeControl = false;
	FString LastKey;
	MBPaint::FCellSet PlacedThisStroke;
	bool bBoxing = false;
	MBPaint::FCell BoxStart;
	MBPaint::FCell BoxEnd;

	// What the preview draws, and in which colour.
	std::vector<MBPaint::FCell> Preview;
	FLinearColor PreviewColour = FLinearColor::White;
};
