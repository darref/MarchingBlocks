// MarchingBlocks Paint for Unreal — THE WORLD EDITING TOOLS, in the level viewport.
//
// Select a MarchingBlocks World actor, then pick "MarchingBlocks" in the Modes menu. The rules live in
// MBCore/MBTools (standard C++, proven by tools_conformance.json); this mode only aims, previews and
// applies inside an undo transaction. Its panel (MarchingBlocksModeToolkit) sits in the mode toolbox: the
// MarchingBlocks tool's right panel, compact; the settings it drives are saved on the actor.
//
//   AIM      Grid — the floor plane (Page Up / Page Down) · Sculpt — the matter itself. Tab alternates them.
//   NAVIGATE Space, on and off: aims at nothing, no click paints, the viewport flies as usual. The aim is
//            kept and comes back; choosing an aim (Tab, or in the panel) leaves navigation.
//   TOOLS    Add (A) · Dig (D) · Select (S) · Rect (G) · Box (B)     Shift does the opposite
//   BRUSH    size 1–7 ([ and ]), sphere / cube / disc; Hollow for the Box
//   SHAPES   tunnel · well · bridge · balcony · stairs (MBCore/MBShapes), always aimed at the matter: one click
//            straight out of a face, or Connect — two clicks on two faces anywhere (two floors for stairs; Esc
//            forgets the first)
//   KEYS     Delete · Esc · arrows move the selection (they follow the camera; Shift + up / down lift)
//            Ctrl+C / Ctrl+X / Ctrl+V copy, cut, paste · F frames all the matter of the visible layers
//   WHEEL    MarchingBlocks' rule (editing_conformance.json, "THE MOUSE WHEEL"): alone it stays the viewport's, EXCEPT
//            during a gesture (a Rect / Box drag: its height; a Room traced: its floors; a paste: its height). Ctrl: the
//            floor; Ctrl + Shift with Stairs: the step. With a selection and Select / Rect / Box: Shift extends it up or
//            down, Alt up widens it flat, Alt down shrinks its edge. Room: Alt floors, Shift rises / sinks. Other shapes:
//            Alt size, Shift length. Add / Dig / Select: Alt the brush size, Shift the next brush shape. Each notch says
//            its value near the mouse. Navigating, the wheel is never ours.
//
// The right mouse button and W A S D Q E are never taken: flying the viewport works in every aim.

#pragma once

#include "CoreMinimal.h"
#include "Tools/UEdMode.h"
#include "Tools/LegacyEdModeInterfaces.h"
#include "MBCore/MBShapes.h"
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
	virtual bool UsesToolkits() const override { return true; }
	virtual void CreateToolkit() override;
	virtual bool InputKey(FEditorViewportClient* ViewportClient, FViewport* Viewport, FKey Key, EInputEvent Event) override;
	virtual bool MouseMove(FEditorViewportClient* ViewportClient, FViewport* Viewport, int32 X, int32 Y) override;
	virtual bool CapturedMouseMove(FEditorViewportClient* ViewportClient, FViewport* Viewport, int32 X, int32 Y) override;
	virtual void Draw(const FSceneView* View, FPrimitiveDrawInterface* PDI) override;
	virtual bool IsSelectionAllowed(AActor* InActor, bool bInSelection) const override { return true; }

	/** The MarchingBlocks World selected in the level — the one the mode and its panel act on. */
	AMarchingBlocksWorld* Target() const;
	/** Applies an aim transition (MBCore's): entering navigation ends the current stroke. */
	void SetAimState(AMarchingBlocksWorld* World, const MBPaint::FAimState& State);
	/** Forgets the first end of a Connect (the panel calls it when the shape or its ends change). */
	void ForgetShapeAnchor() { bHasShapeAnchor = false; Preview.clear(); }

private:
	bool MouseRay(FEditorViewportClient* ViewportClient, FViewport* Viewport, FVector& Origin, FVector& Direction) const;
	bool Aimed(AMarchingBlocksWorld* World, const FVector& Origin, const FVector& Direction, bool bAdd, MBPaint::FHit& Hit);
	bool BoxCorner(AMarchingBlocksWorld* World, const FVector& Origin, const FVector& Direction, MBPaint::FCell& Corner);
	void Hover(FEditorViewportClient* ViewportClient, FViewport* Viewport);
	void Touch(AMarchingBlocksWorld* World, MBPaint::EBrushTool BrushTool, const MBPaint::FCell& Anchor,
		const MBPaint::FHit& Hit, const std::vector<MBPaint::FCell>& Cells, bool bDeselect);
	bool HandleShortcut(AMarchingBlocksWorld* World, FViewport* Viewport, FKey Key);
	MBPaint::FCell ArrowOffset(AMarchingBlocksWorld* World, FEditorViewportClient* ViewportClient, FKey Key, bool bShift) const;
	MBPaint::EBrushTool Gesture(const AMarchingBlocksWorld* World, bool bInverse) const;
	bool WaitingForFirstEnd(const AMarchingBlocksWorld* World) const;
	MBPaint::FShapeRequest ShapeRequest(const AMarchingBlocksWorld* World, const MBPaint::FHit& Hit) const;
	void HoverShape(AMarchingBlocksWorld* World, const FVector& Origin, const FVector& Direction);
	void ApplyRoom(AMarchingBlocksWorld* World, const MBPaint::FCell& A, const MBPaint::FCell& B);
	void ClickShape(AMarchingBlocksWorld* World, const FVector& Origin, const FVector& Direction);
	/** The wheel rule; true when the notch was ours (the viewport then does not zoom). */
	bool Wheel(AMarchingBlocksWorld* World, FEditorViewportClient* ViewportClient, FViewport* Viewport, int32 Notch);
	/** Says a wheel notch's value: in the panel and on the viewport, for a moment. */
	void Say(AMarchingBlocksWorld* World, const FString& Text);
	/** The paste anchor under the mouse, lifted by the wheel. */
	MBPaint::FCell PasteAnchor(const MBPaint::FHit& Hit) const;

	// The current stroke.
	bool bStroking = false;
	bool bStrokeInverse = false;
	bool bStrokeControl = false;
	FString LastKey;
	MBPaint::FCellSet PlacedThisStroke;
	bool bBoxing = false;
	MBPaint::FCell BoxStart;
	MBPaint::FCell BoxEnd;
	// The first end of a Connect.
	bool bHasShapeAnchor = false;
	MBPaint::FHit ShapeAnchor;

	// A paste preview lifted by the wheel, in cells.
	int32 PasteLift = 0;

	// What the preview draws, and in which colour.
	std::vector<MBPaint::FCell> Preview;
	FLinearColor PreviewColour = FLinearColor::White;
};
