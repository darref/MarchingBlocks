// MarchingBlocks Paint for Unreal — the editor mode (see MarchingBlocksEdMode.h).

#include "MarchingBlocksEdMode.h"

#include "MarchingBlocksModeToolkit.h"
#include "EditorViewportClient.h"
#include "Engine/Engine.h"
#include "Engine/Selection.h"
#include "Editor.h"
#include "MarchingBlocksWorld.h"
#include "SceneManagement.h"
#include "SceneView.h"
#include "ScopedTransaction.h"

#define LOCTEXT_NAMESPACE "MarchingBlocksEdMode"

const FEditorModeID UMarchingBlocksEdMode::ModeId = TEXT("EM_MarchingBlocks");

namespace MarchingBlocksEdModeDetail
{
	const FLinearColor AddColour(0.55f, 0.82f, 0.45f);
	const FLinearColor DigColour(0.9f, 0.35f, 0.25f);
	const FLinearColor SelectColour(0.95f, 0.8f, 0.3f);
	const FLinearColor SelectionColour(0.35f, 0.7f, 1.f);
	// Past a few thousand wire boxes the viewport crawls; the counts are in the panel anyway.
	constexpr int32 MaxDrawn = 3000;

	MBPaint::EBrushShape Shape(EMarchingBlocksBrushShape S)
	{
		return S == EMarchingBlocksBrushShape::Cube ? MBPaint::EBrushShape::Cube
			: S == EMarchingBlocksBrushShape::Disc ? MBPaint::EBrushShape::Disc : MBPaint::EBrushShape::Sphere;
	}
}

UMarchingBlocksEdMode::UMarchingBlocksEdMode()
{
	Info = FEditorModeInfo(ModeId, LOCTEXT("ModeName", "MarchingBlocks"),
		FSlateIcon(FMarchingBlocksModeToolkit::StyleName, "MarchingBlocks.world"), true);
}

void UMarchingBlocksEdMode::CreateToolkit()
{
	Toolkit = MakeShareable(new FMarchingBlocksModeToolkit);
}

void UMarchingBlocksEdMode::Exit()
{
	bStroking = false;
	bBoxing = false;
	bHasShapeAnchor = false;
	Preview.clear();
	Super::Exit();
}

AMarchingBlocksWorld* UMarchingBlocksEdMode::Target() const
{
	USelection* Selected = GEditor ? GEditor->GetSelectedActors() : nullptr;
	if (!Selected) return nullptr;
	for (FSelectionIterator It(*Selected); It; ++It)
		if (AMarchingBlocksWorld* World = Cast<AMarchingBlocksWorld>(*It)) return World;
	return nullptr;
}

bool UMarchingBlocksEdMode::MouseRay(FEditorViewportClient* ViewportClient, FViewport* Viewport, FVector& Origin, FVector& Direction) const
{
	FSceneViewFamilyContext Family(FSceneViewFamily::ConstructionValues(Viewport, ViewportClient->GetScene(), ViewportClient->EngineShowFlags)
		.SetRealtimeUpdate(ViewportClient->IsRealtime()));
	FSceneView* View = ViewportClient->CalcSceneView(&Family);
	if (!View) return false;
	const FViewportCursorLocation Cursor(View, ViewportClient, Viewport->GetMouseX(), Viewport->GetMouseY());
	Origin = Cursor.GetOrigin();
	Direction = Cursor.GetDirection();
	return true;
}

// The matter in Sculpt (when the ray meets it), the floor otherwise.
bool UMarchingBlocksEdMode::Aimed(AMarchingBlocksWorld* World, const FVector& Origin, const FVector& Direction, bool bAdd, MBPaint::FHit& Hit)
{
	Hit = MBPaint::FHit();
	if (World->Aim == EMarchingBlocksAim::Sculpt)
	{
		Hit = World->RayAgainstCells(Origin, Direction, bAdd ? &PlacedThisStroke : nullptr);
		if (Hit.bTouched) return true;
	}
	MBPaint::FCell Cell;
	if (!World->CellUnderRay(Origin, Direction, Cell)) return false;
	Hit.bTouched = false;
	Hit.Cell = Cell;
	return true;
}

namespace MarchingBlocksEdModeDetail
{
	// The room is DRAWN like the Rect — flat on the floor whatever the aim — not clicked like the other shapes.
	bool DrawingRoom(const AMarchingBlocksWorld* World)
	{
		return World->Tool == EMarchingBlocksTool::Shape && World->SpecialShape == EMarchingBlocksSpecialShape::Room;
	}
}

// The Rect ignores the aim: it always lies flat on the floor — the gesture that draws a room's floor. So does
// the room itself.
bool UMarchingBlocksEdMode::BoxCorner(AMarchingBlocksWorld* World, const FVector& Origin, const FVector& Direction, MBPaint::FCell& Corner)
{
	if (World->Tool == EMarchingBlocksTool::Rect || MarchingBlocksEdModeDetail::DrawingRoom(World))
		return World->CellUnderRay(Origin, Direction, Corner);
	MBPaint::FHit Hit;
	if (!Aimed(World, Origin, Direction, false, Hit)) return false;
	Corner = Hit.Cell;
	return true;
}

MBPaint::EBrushTool UMarchingBlocksEdMode::Gesture(const AMarchingBlocksWorld* World, bool bInverse) const
{
	if (World->Tool == EMarchingBlocksTool::Add) return bInverse ? MBPaint::EBrushTool::Dig : MBPaint::EBrushTool::Add;
	if (World->Tool == EMarchingBlocksTool::Dig) return bInverse ? MBPaint::EBrushTool::Add : MBPaint::EBrushTool::Dig;
	return MBPaint::EBrushTool::Select;
}

void UMarchingBlocksEdMode::Touch(AMarchingBlocksWorld* World, MBPaint::EBrushTool BrushTool, const MBPaint::FCell& Anchor,
	const MBPaint::FHit& Hit, const std::vector<MBPaint::FCell>& Cells, bool bDeselect)
{
	// The same cell under the same face twice in a row is nothing new.
	const FString Key = FString::Printf(TEXT("%d,%d,%d|%d,%d,%d"), Anchor.X, Anchor.Y, Anchor.Z, Hit.Normal.X, Hit.Normal.Y, Hit.Normal.Z);
	if (Key == LastKey) return;
	LastKey = Key;
	if (BrushTool == MBPaint::EBrushTool::Select)
	{
		// MBCore's rule (editing_conformance.json, select_brush): the full cells only, or every cell with "Select empty
		// cells too"; the inverse gesture removes them, full or empty.
		const MBPaint::FCellSet& Full = World->GetCells();
		MBPaint::Editing::SelectBrush(World->Selection, Cells, [&Full](const MBPaint::FCell& C) { return Full.count(C) > 0; },
			World->bSelectEmptyCells, bDeselect);
		return;
	}
	const MBPaint::FCellSet& Full = World->GetCells();
	const MBPaint::FChange Change = MBPaint::Tools::Modify(BrushTool, Cells, [&Full](const MBPaint::FCell& C) { return Full.count(C) > 0; });
	if (Change.IsEmpty()) return;
	// The stroke lock: what this stroke placed is transparent to its own ray, or dragging would build a
	// tower towards the camera instead of a skin on the surface.
	for (const MBPaint::FCell& C : Change.Set) PlacedThisStroke.insert(C);
	World->Modify();
	World->Apply(Change);
}

void UMarchingBlocksEdMode::Hover(FEditorViewportClient* ViewportClient, FViewport* Viewport)
{
	using namespace MarchingBlocksEdModeDetail;
	Preview.clear();
	AMarchingBlocksWorld* World = Target();
	// Navigating aims at nothing, so it promises nothing: no preview.
	if (!World || World->GetAimState().bNavigating) return;
	FVector Origin, Direction;
	if (!MouseRay(ViewportClient, Viewport, Origin, Direction)) return;

	if (World->bPasting)
	{
		MBPaint::FHit Hit;
		if (!Aimed(World, Origin, Direction, true, Hit)) return;
		const MBPaint::FCell Anchor = PasteAnchor(Hit);
		for (const MBPaint::FCell& D : World->Clipboard) Preview.push_back(Anchor + D);
		PreviewColour = AddColour;
		return;
	}
	if (MarchingBlocksEdModeDetail::DrawingRoom(World))
	{
		MBPaint::FCell Corner;
		const bool bHas = BoxCorner(World, Origin, Direction, Corner);
		PreviewColour = AddColour;
		if (!bBoxing)
		{
			if (bHas) Preview.push_back(Corner);
			return;
		}
		if (bHas) BoxEnd = Corner;
		const MBPaint::FShapeResult R = MBPaint::Shapes::Room(World->GetCells(), BoxStart, BoxEnd, World->RoomFloors, World->bRoomUp);
		Preview = MBPaint::Tools::Sorted(R.Set);
		return;
	}
	if (World->Tool == EMarchingBlocksTool::Shape)
	{
		HoverShape(World, Origin, Direction);
		return;
	}
	if (World->Tool == EMarchingBlocksTool::Variant)
	{
		const MBPaint::FHit Hit = World->RayAgainstCells(Origin, Direction);
		if (Hit.bTouched) Preview.push_back(Hit.Cell);
		return;
	}
	if (World->Tool == EMarchingBlocksTool::Rect || World->Tool == EMarchingBlocksTool::Box)
	{
		MBPaint::FCell Corner;
		const bool bHas = BoxCorner(World, Origin, Direction, Corner);
		if (bBoxing)
		{
			if (bHas) BoxEnd = Corner;
			Preview = MBPaint::Tools::Sorted(MBPaint::Tools::Box(BoxStart, BoxEnd, World->bHollowBox && World->Tool == EMarchingBlocksTool::Box));
			PreviewColour = bStrokeControl ? DigColour : SelectColour;
		}
		else if (bHas)
		{
			Preview.push_back(Corner);
			PreviewColour = SelectColour;
		}
		return;
	}
	const bool bInverse = bStroking ? bStrokeInverse : Viewport->KeyState(EKeys::LeftShift) || Viewport->KeyState(EKeys::RightShift);
	const MBPaint::EBrushTool G = Gesture(World, bInverse);
	MBPaint::FHit Hit;
	if (!Aimed(World, Origin, Direction, G == MBPaint::EBrushTool::Add, Hit)) return;
	const MBPaint::FCell Anchor = MBPaint::Tools::Anchor(G, Hit);
	Preview = MBPaint::Tools::Brush(Anchor, Hit.Normal, World->BrushSize, Shape(World->BrushShape));
	PreviewColour = G == MBPaint::EBrushTool::Add ? AddColour : G == MBPaint::EBrushTool::Dig ? DigColour : SelectColour;
	if (bStroking) Touch(World, G, Anchor, Hit, Preview, bStrokeControl);
}

bool UMarchingBlocksEdMode::MouseMove(FEditorViewportClient* ViewportClient, FViewport* Viewport, int32 X, int32 Y)
{
	Hover(ViewportClient, Viewport);
	return false;
}

bool UMarchingBlocksEdMode::CapturedMouseMove(FEditorViewportClient* ViewportClient, FViewport* Viewport, int32 X, int32 Y)
{
	if (!bStroking && !bBoxing) return false;
	Hover(ViewportClient, Viewport);
	return true;
}

bool UMarchingBlocksEdMode::InputKey(FEditorViewportClient* ViewportClient, FViewport* Viewport, FKey Key, EInputEvent Event)
{
	using namespace MarchingBlocksEdModeDetail;
	AMarchingBlocksWorld* World = Target();
	if (!World) return false;
	const bool bShift = Viewport->KeyState(EKeys::LeftShift) || Viewport->KeyState(EKeys::RightShift);
	const bool bControl = Viewport->KeyState(EKeys::LeftControl) || Viewport->KeyState(EKeys::RightControl);
	const bool bFlying = Viewport->KeyState(EKeys::RightMouseButton);

	// Navigating takes nothing but Space (back to painting) and Tab (an aim, which also leaves navigation):
	// the mouse and every other key fly the viewport, as usual. No click paints.
	if (World->GetAimState().bNavigating)
	{
		if (Event == IE_Pressed && !bFlying && (Key == EKeys::SpaceBar || Key == EKeys::Tab))
		{
			SetAimState(World, Key == EKeys::Tab ? MBPaint::Tools::Tab(World->GetAimState())
				: MBPaint::Tools::ToggleNavigate(World->GetAimState()));
			return true;
		}
		return false;
	}

	if (Key == EKeys::LeftMouseButton && !Viewport->KeyState(EKeys::LeftAlt))
	{
		FVector Origin, Direction;
		if (Event == IE_Pressed && MouseRay(ViewportClient, Viewport, Origin, Direction))
		{
			if (World->bPasting)
			{
				MBPaint::FHit Hit;
				if (Aimed(World, Origin, Direction, true, Hit))
				{
					const FScopedTransaction Transaction(LOCTEXT("Paste", "Paste"));
					World->Modify();
					const MBPaint::FChange Change = MBPaint::Tools::Paste(World->GetCells(), World->Clipboard, PasteAnchor(Hit));
					World->Apply(Change);
					World->Selection = Change.Selection;
					World->bPasting = false;
					PasteLift = 0;
				}
				return true;
			}
			if (MarchingBlocksEdModeDetail::DrawingRoom(World))
			{
				MBPaint::FCell Corner;
				if (!BoxCorner(World, Origin, Direction, Corner)) return true;
				bBoxing = true;
				BoxStart = BoxEnd = Corner;
				return true;
			}
			if (World->Tool == EMarchingBlocksTool::Shape)
			{
				ClickShape(World, Origin, Direction);
				return true;
			}
			if (World->Tool == EMarchingBlocksTool::Variant)
			{
				MBPaint::FCell Vertex;
				if (World->TileUnderRay(Origin, Direction, Vertex))
					World->ClickVariant(Vertex, Viewport->KeyState(EKeys::LeftShift) || Viewport->KeyState(EKeys::RightShift));
				else World->Status = TEXT("Variant — point at a tile of this layer.");
				return true;
			}
			if (World->Tool == EMarchingBlocksTool::Rect || World->Tool == EMarchingBlocksTool::Box)
			{
				MBPaint::FCell Corner;
				if (!BoxCorner(World, Origin, Direction, Corner)) return true;
				bBoxing = true;
				bStrokeControl = bControl;
				bStrokeInverse = bShift;
				BoxStart = BoxEnd = Corner;
				return true;
			}
			bStroking = true;
			bStrokeInverse = bShift;
			bStrokeControl = bControl;
			LastKey.Reset();
			PlacedThisStroke.clear();
			GEditor->BeginTransaction(LOCTEXT("Stroke", "MarchingBlocks stroke"));
			if (World->Tool == EMarchingBlocksTool::Select && !bShift && !bControl) World->Selection.clear();
			Hover(ViewportClient, Viewport);
			return true;
		}
		if (Event == IE_Released)
		{
			if (MarchingBlocksEdModeDetail::DrawingRoom(World))
			{
				if (!bBoxing) return true;
				bBoxing = false;
				ApplyRoom(World, BoxStart, BoxEnd);
				return true;
			}
			if (World->Tool == EMarchingBlocksTool::Shape) return true;
			if (bBoxing)
			{
				const MBPaint::FCellSet Volume = MBPaint::Tools::Box(BoxStart, BoxEnd, World->bHollowBox && World->Tool == EMarchingBlocksTool::Box);
				if (Volume.empty())
					World->Status = FString::Printf(TEXT("Box too large — more than %lld cells. Draw a smaller one."), MBPaint::Tools::BoxVolumeMax);
				else
				{
					if (!bStrokeInverse && !bStrokeControl) World->Selection.clear();
					for (const MBPaint::FCell& C : Volume)
					{
						if (bStrokeControl) World->Selection.erase(C);
						else World->Selection.insert(C);
					}
				}
				bBoxing = false;
				return true;
			}
			if (bStroking)
			{
				bStroking = false;
				GEditor->EndTransaction();
				return true;
			}
		}
		return false;
	}

	if (Key == EKeys::MouseScrollUp || Key == EKeys::MouseScrollDown)
	{
		if (Event != IE_Pressed || bFlying) return false;
		return Wheel(World, ViewportClient, Viewport, Key == EKeys::MouseScrollUp ? 1 : -1);
	}
	if (Event != IE_Pressed || bFlying) return false;
	if (Key == EKeys::F && !bControl && !bShift)
	{
		// F frames ALL the matter of the visible layers (MarchingBlocks' F), not the selected actor.
		FBox Bounds;
		if (!World->VisibleMatterBounds(Bounds)) return false;
		ViewportClient->FocusViewportOnBox(Bounds);
		return true;
	}
	if (bControl)
	{
		if (Key == EKeys::C) { World->CopySelection(); return true; }
		if (Key == EKeys::X) { World->CutSelection(); return true; }
		if (Key == EKeys::V) { World->PasteClipboard(); return true; }
		return false;
	}
	if (Key == EKeys::Up || Key == EKeys::Down || Key == EKeys::Left || Key == EKeys::Right)
	{
		if (World->Selection.empty()) return false;
		World->MoveSelection(ArrowOffset(World, ViewportClient, Key, bShift));
		return true;
	}
	return HandleShortcut(World, Viewport, Key);
}

// The transitions are MBCore's (Tools::Tab, ToggleNavigate, ChooseAim — proven by the core-runner); this
// only applies them. ⚠ Entering navigation ENDS the current stroke: its release would come while navigating,
// where no click is taken, and the undo transaction would stay open.
void UMarchingBlocksEdMode::SetAimState(AMarchingBlocksWorld* World, const MBPaint::FAimState& State)
{
	World->SetAimState(State);
	if (State.bNavigating)
	{
		if (bStroking)
		{
			bStroking = false;
			GEditor->EndTransaction();
		}
		bBoxing = false;
	}
	Preview.clear();
}

bool UMarchingBlocksEdMode::HandleShortcut(AMarchingBlocksWorld* World, FViewport* Viewport, FKey Key)
{
	const bool bShaping = World->Tool == EMarchingBlocksTool::Shape;
	if (Key == EKeys::A || Key == EKeys::D || Key == EKeys::S || Key == EKeys::G || Key == EKeys::B || Key == EKeys::V) bHasShapeAnchor = false;
	if (Key == EKeys::A) World->Tool = EMarchingBlocksTool::Add;
	else if (Key == EKeys::D) World->Tool = EMarchingBlocksTool::Dig;
	else if (Key == EKeys::S) World->Tool = EMarchingBlocksTool::Select;
	else if (Key == EKeys::G) World->Tool = EMarchingBlocksTool::Rect;
	else if (Key == EKeys::B) World->Tool = EMarchingBlocksTool::Box;
	else if (Key == EKeys::V) World->Tool = EMarchingBlocksTool::Variant;
	else if (Key == EKeys::Tab) SetAimState(World, MBPaint::Tools::Tab(World->GetAimState()));
	else if (Key == EKeys::SpaceBar) SetAimState(World, MBPaint::Tools::ToggleNavigate(World->GetAimState()));
	else if (Key == EKeys::LeftBracket && MarchingBlocksEdModeDetail::DrawingRoom(World))
		World->RoomFloors = FMath::Max(1, World->RoomFloors - 1);
	else if (Key == EKeys::RightBracket && MarchingBlocksEdModeDetail::DrawingRoom(World))
		World->RoomFloors = FMath::Min(MBPaint::Shapes::RoomFloorsMax, World->RoomFloors + 1);
	else if (Key == EKeys::LeftBracket)
	{
		if (bShaping) World->ShapeSize = FMath::Max(1, World->ShapeSize - 1);
		else World->BrushSize = FMath::Max(1, World->BrushSize - 1);
	}
	else if (Key == EKeys::RightBracket)
	{
		if (bShaping) World->ShapeSize = FMath::Min(7, World->ShapeSize + 1);
		else World->BrushSize = FMath::Min(7, World->BrushSize + 1);
	}
	else if (Key == EKeys::PageUp || Key == EKeys::PageDown)
	{
		const FScopedTransaction Transaction(LOCTEXT("Floor", "Change floor"));
		World->Modify();
		World->Floor += Key == EKeys::PageUp ? 1 : -1;
	}
	else if (Key == EKeys::Delete) World->DeleteSelected();
	else if (Key == EKeys::Escape)
	{
		if (World->bPasting || bBoxing || bHasShapeAnchor) { World->bPasting = false; bBoxing = false; bHasShapeAnchor = false; PasteLift = 0; }
		else World->ClearSelection();
	}
	else return false;
	Preview.clear();
	return true;
}

// The room between two corners of the floor: refused and said, or applied as ONE transaction.
void UMarchingBlocksEdMode::ApplyRoom(AMarchingBlocksWorld* World, const MBPaint::FCell& A, const MBPaint::FCell& B)
{
	const MBPaint::FShapeResult R = MBPaint::Shapes::Room(World->GetCells(), A, B, World->RoomFloors, World->bRoomUp);
	if (!R.Error.empty())
	{
		World->Status = R.Error == "too_small" ? FString(TEXT("Room — at least 3 x 3 cells: draw a bigger rectangle."))
			: FString::Printf(TEXT("Room — too large: more than %lld cells."), MBPaint::Shapes::VolumeMax);
		return;
	}
	MBPaint::FChange Change;
	Change.Set = R.Set;
	Change.Clear = R.Clear;
	const FScopedTransaction Transaction(LOCTEXT("Room", "MarchingBlocks room"));
	World->Modify();
	World->Apply(Change);
	World->Status = FString::Printf(TEXT("Room — %d cell(s) of shell, %d dug out."), static_cast<int32>(R.Set.size()),
		static_cast<int32>(R.Clear.size()));
}

// ── Special shapes ───────────────────────────────────────────────────────────────────────────────────
//
// A shape starts from a FACE, so it always aims at the matter, whatever the aim (the floor has no face).

namespace MarchingBlocksEdModeDetail
{
	const TCHAR* ShapeName(EMarchingBlocksSpecialShape S)
	{
		return S == EMarchingBlocksSpecialShape::Well ? TEXT("Well") : S == EMarchingBlocksSpecialShape::Bridge ? TEXT("Bridge")
			: S == EMarchingBlocksSpecialShape::Balcony ? TEXT("Balcony") : S == EMarchingBlocksSpecialShape::Stairs ? TEXT("Stairs")
			: TEXT("Tunnel");
	}

	FString ShapeError(const std::string& Code)
	{
		if (Code == "needs_a_wall") return TEXT("click a WALL, a side face of the matter.");
		if (Code == "needs_floor_or_ceiling") return TEXT("click a FLOOR or a CEILING, a top or bottom face.");
		if (Code == "needs_a_floor") return TEXT("click two FLOORS, the top face of the matter.");
		if (Code == "too_steep") return TEXT("too steep: one cell up for each cell across at most. Pick two floors further apart.");
		if (Code == "same_cell") return TEXT("the second end must be another cell.");
		if (Code == "too_far") return TEXT("the two ends are too far apart.");
		if (Code == "nothing_in_front") return TEXT("no wall in front within reach. Raise Shape Length, or Connect two walls.");
		if (Code == "too_large") return TEXT("too large. Make it smaller or shorter.");
		return UTF8_TO_TCHAR(Code.c_str());
	}
}

bool UMarchingBlocksEdMode::WaitingForFirstEnd(const AMarchingBlocksWorld* World) const
{
	return World->bConnectEnds && !bHasShapeAnchor && World->SpecialShape != EMarchingBlocksSpecialShape::Balcony;
}

MBPaint::FShapeRequest UMarchingBlocksEdMode::ShapeRequest(const AMarchingBlocksWorld* World, const MBPaint::FHit& Hit) const
{
	MBPaint::FShapeRequest R = World->ShapeSettings();
	R.A = Hit.Cell;
	R.FaceA = Hit.Normal;
	if (World->bConnectEnds && bHasShapeAnchor && World->SpecialShape != EMarchingBlocksSpecialShape::Balcony)
	{
		R.bConnect = true;
		R.A = ShapeAnchor.Cell;
		R.FaceA = ShapeAnchor.Normal;
		R.B = Hit.Cell;
		R.FaceB = Hit.Normal;
	}
	return R;
}

void UMarchingBlocksEdMode::HoverShape(AMarchingBlocksWorld* World, const FVector& Origin, const FVector& Direction)
{
	using namespace MarchingBlocksEdModeDetail;
	const MBPaint::FHit Hit = World->RayAgainstCells(Origin, Direction);
	PreviewColour = SelectColour;
	if (bHasShapeAnchor) Preview.push_back(ShapeAnchor.Cell);
	if (!Hit.bTouched) return;
	if (WaitingForFirstEnd(World))
	{
		Preview.push_back(Hit.Cell);
		return;
	}
	const MBPaint::FShapeResult R = MBPaint::Shapes::Build(World->GetCells(), ShapeRequest(World, Hit));
	if (!R.Error.empty())
	{
		Preview.push_back(Hit.Cell);
		PreviewColour = DigColour;
		return;
	}
	const std::vector<MBPaint::FCell> Cells = MBPaint::Tools::Sorted(R.Clear.empty() ? R.Set : R.Clear);
	Preview.insert(Preview.end(), Cells.begin(), Cells.end());
	PreviewColour = R.Clear.empty() ? AddColour : DigColour;
}

// A click on the matter: the first end of a Connect, or the shape itself — ONE undo transaction.
void UMarchingBlocksEdMode::ClickShape(AMarchingBlocksWorld* World, const FVector& Origin, const FVector& Direction)
{
	using namespace MarchingBlocksEdModeDetail;
	const MBPaint::FHit Hit = World->RayAgainstCells(Origin, Direction);
	if (!Hit.bTouched) return;
	const FString Name = ShapeName(World->SpecialShape);
	if (WaitingForFirstEnd(World))
	{
		const MBPaint::FShapeRequest R = World->ShapeSettings();
		const MBPaint::FCell N = MBPaint::Shapes::NormalFor(R.Shape, World->GetCells(), Hit.Cell, Hit.Normal, true);
		if (N.X == 0 && N.Y == 0 && N.Z == 0)
			World->Status = Name + TEXT(" — ") + ShapeError(MBPaint::Shapes::EndError(R.Shape, true));
		else
		{
			bHasShapeAnchor = true;
			ShapeAnchor = Hit;
			World->Status = Name + TEXT(" — first end set. Click the second one (Esc forgets it).");
		}
		return;
	}
	const MBPaint::FShapeResult R = MBPaint::Shapes::Build(World->GetCells(), ShapeRequest(World, Hit));
	if (!R.Error.empty())
	{
		World->Status = Name + TEXT(" — ") + ShapeError(R.Error);
		return;
	}
	bHasShapeAnchor = false;
	MBPaint::FChange Change;
	Change.Set = R.Set;
	Change.Clear = R.Clear;
	const FScopedTransaction Transaction(FText::FromString(TEXT("MarchingBlocks ") + Name));
	World->Modify();
	const int32 Count = World->Apply(Change);
	World->Status = FString::Printf(TEXT("%s — %d cell(s) changed%s. Ctrl+Z undoes it."), *Name, Count,
		R.Repaired > 0 ? *FString::Printf(TEXT(", %d more so that no two cells touch by an edge only"), R.Repaired) : TEXT(""));
	Preview.clear();
}

// The arrows FOLLOW THE CAMERA: "up" moves away from you along the format axis (X or Z) closest to where
// the camera looks; Shift + up / down raise and lower.
MBPaint::FCell UMarchingBlocksEdMode::ArrowOffset(AMarchingBlocksWorld* World, FEditorViewportClient* ViewportClient, FKey Key, bool bShift) const
{
	if (bShift && (Key == EKeys::Up || Key == EKeys::Down)) return MBPaint::FCell(0, Key == EKeys::Up ? 1 : -1, 0);
	const FRotator Rotation = ViewportClient->GetViewRotation();
	const FVector Forward = World->WorldDirectionToFormat(Rotation.Vector());
	const FVector Right = World->WorldDirectionToFormat(FRotationMatrix(Rotation).GetScaledAxis(EAxis::Y));
	auto Axis = [](const FVector& V)
	{
		return FMath::Abs(V.X) >= FMath::Abs(V.Z) ? MBPaint::FCell(V.X >= 0 ? 1 : -1, 0, 0) : MBPaint::FCell(0, 0, V.Z >= 0 ? 1 : -1);
	};
	const MBPaint::FCell F = Axis(Forward);
	const MBPaint::FCell R = Axis(Right);
	if (Key == EKeys::Up) return F;
	if (Key == EKeys::Down) return MBPaint::FCell(-F.X, 0, -F.Z);
	if (Key == EKeys::Right) return R;
	return MBPaint::FCell(-R.X, 0, -R.Z);
}

MBPaint::FCell UMarchingBlocksEdMode::PasteAnchor(const MBPaint::FHit& Hit) const
{
	return MBPaint::Tools::Anchor(MBPaint::EBrushTool::Add, Hit) + MBPaint::FCell(0, PasteLift, 0);
}

void UMarchingBlocksEdMode::Say(AMarchingBlocksWorld* World, const FString& Text)
{
	World->Status = Text;
	// ⚠ NOT NEAR THE MOUSE, as MarchingBlocks says it: in Unreal 5.8 a mode draws on the viewport's canvas only through
	// ILegacyEdModeWidgetInterface (a dozen abstract gizmo methods). The value is said on the viewport (top left), for a moment.
	if (GEngine) GEngine->AddOnScreenDebugMessage(static_cast<uint64>(0x4D42574845454CULL), 1.5f, FColor(140, 209, 115), Text);
}

// THE MOUSE WHEEL — MarchingBlocks' rule (app/editor.gd, _molette_du_monde; editing_conformance.json "THE MOUSE WHEEL").
// The EFFECTS on cells are MBCore's (Editing::Extrude extend, WidenFlat, ShrinkEdge — with cases); which setting a
// modifier drives is a UI rule, judged by hand. ⚠ The wheel is taken ONLY when a gesture or a modifier asks for it:
// alone, it stays Unreal's (zoom, or the camera speed while flying). The Details panel is not ours.
bool UMarchingBlocksEdMode::Wheel(AMarchingBlocksWorld* World, FEditorViewportClient* ViewportClient, FViewport* Viewport, int32 Notch)
{
	using namespace MarchingBlocksEdModeDetail;
	const bool bShift = Viewport->KeyState(EKeys::LeftShift) || Viewport->KeyState(EKeys::RightShift);
	const bool bControl = Viewport->KeyState(EKeys::LeftControl) || Viewport->KeyState(EKeys::RightControl);
	const bool bAlt = Viewport->KeyState(EKeys::LeftAlt) || Viewport->KeyState(EKeys::RightAlt);
	const bool bRoom = DrawingRoom(World);
	const bool bShape = World->Tool == EMarchingBlocksTool::Shape;
	// 1. During a gesture, the wheel shapes it, without a modifier.
	if (!bShift && !bControl && !bAlt)
	{
		if (bBoxing && bRoom)
		{
			World->RoomFloors = FMath::Clamp(World->RoomFloors + Notch, 1, MBPaint::Shapes::RoomFloorsMax);
			Say(World, FString::Printf(TEXT("Room — %d floor(s)"), World->RoomFloors));
		}
		else if (bBoxing && (World->Tool == EMarchingBlocksTool::Rect || World->Tool == EMarchingBlocksTool::Box))
		{
			// One cell per notch: a flat Rect becomes a box.
			BoxEnd.Y += Notch;
			Say(World, FString::Printf(TEXT("Height %d"), FMath::Abs(BoxEnd.Y - BoxStart.Y) + 1));
		}
		else if (World->bPasting)
		{
			PasteLift += Notch;
			Say(World, FString::Printf(TEXT("Paste height %+d"), PasteLift));
		}
		else return false;
		Hover(ViewportClient, Viewport);
		return true;
	}
	// 2. Ctrl + Shift with the Stairs shape: its step. Ctrl: the floor.
	if (bControl && bShift && bShape && World->SpecialShape == EMarchingBlocksSpecialShape::Stairs)
	{
		World->StairsStep = FMath::Clamp(World->StairsStep + Notch, 1, MBPaint::Shapes::StepMax);
		Say(World, FString::Printf(TEXT("Stairs step %d"), World->StairsStep));
		return true;
	}
	if (bControl)
	{
		const FScopedTransaction Transaction(LOCTEXT("Floor", "Change floor"));
		World->Modify();
		World->Floor += Notch;
		Say(World, FString::Printf(TEXT("Floor %d"), World->Floor));
		Hover(ViewportClient, Viewport);
		return true;
	}
	// 3. A selection and a selection tool: Shift extends it, Alt widens it (up) or shrinks its edge (down). Nothing is set.
	const bool bSelectionTool = World->Tool == EMarchingBlocksTool::Select || World->Tool == EMarchingBlocksTool::Rect
		|| World->Tool == EMarchingBlocksTool::Box;
	if (!World->Selection.empty() && bSelectionTool)
	{
		if (bShift) World->Extrude(Notch > 0 ? MBPaint::EExtrudeDirection::Up : MBPaint::EExtrudeDirection::Down, MBPaint::EExtrudeMode::Extend);
		else if (Notch > 0) World->Widen();
		else World->Shrink();
		Say(World, FString::Printf(TEXT("%s — %d selected"), bShift ? (Notch > 0 ? TEXT("Extend up") : TEXT("Extend down"))
			: Notch > 0 ? TEXT("Widen") : TEXT("Shrink"), static_cast<int32>(World->Selection.size())));
		return true;
	}
	// 4. The room: Alt its floors, Shift rises / sinks. Other shapes: Alt the size, Shift the length.
	if (bRoom)
	{
		if (bAlt)
		{
			World->RoomFloors = FMath::Clamp(World->RoomFloors + Notch, 1, MBPaint::Shapes::RoomFloorsMax);
			Say(World, FString::Printf(TEXT("Room — %d floor(s)"), World->RoomFloors));
		}
		else
		{
			World->bRoomUp = Notch > 0;
			Say(World, World->bRoomUp ? TEXT("Room — rises") : TEXT("Room — sinks"));
		}
		Hover(ViewportClient, Viewport);
		return true;
	}
	if (bShape)
	{
		if (bAlt)
		{
			World->ShapeSize = FMath::Clamp(World->ShapeSize + Notch, 1, 7);
			Say(World, FString::Printf(TEXT("Shape size %d"), World->ShapeSize));
		}
		else
		{
			World->ShapeLength = FMath::Clamp(World->ShapeLength + Notch, 1, MBPaint::Shapes::LengthMax);
			Say(World, FString::Printf(TEXT("Shape length %d"), World->ShapeLength));
		}
		Hover(ViewportClient, Viewport);
		return true;
	}
	// 5. Add / Dig / Select: Alt the brush size, Shift the next brush shape.
	if (World->Tool == EMarchingBlocksTool::Add || World->Tool == EMarchingBlocksTool::Dig || World->Tool == EMarchingBlocksTool::Select)
	{
		if (bAlt)
		{
			World->BrushSize = FMath::Clamp(World->BrushSize + Notch, 1, 7);
			Say(World, FString::Printf(TEXT("Brush size %d"), World->BrushSize));
		}
		else
		{
			const int32 Next = (static_cast<int32>(World->BrushShape) + (Notch > 0 ? 1 : 2)) % 3;
			World->BrushShape = static_cast<EMarchingBlocksBrushShape>(Next);
			Say(World, World->BrushShape == EMarchingBlocksBrushShape::Sphere ? TEXT("Brush — sphere")
				: World->BrushShape == EMarchingBlocksBrushShape::Cube ? TEXT("Brush — cube") : TEXT("Brush — disc"));
		}
		Hover(ViewportClient, Viewport);
		return true;
	}
	return false;
}

void UMarchingBlocksEdMode::Draw(const FSceneView* View, FPrimitiveDrawInterface* PDI)
{
	using namespace MarchingBlocksEdModeDetail;
	AMarchingBlocksWorld* World = Target();
	if (!World) return;
	auto DrawCell = [&](const MBPaint::FCell& C, const FLinearColor& Colour, double Inset)
	{
		const double H = 0.5 - Inset;
		DrawWireBox(PDI, World->CellMatrix(C), FBox(FVector(-H), FVector(H)), Colour, SDPG_Foreground);
	};
	int32 N = 0;
	for (const MBPaint::FCell& C : World->Selection)
	{
		if (++N > MaxDrawn) break;
		DrawCell(C, SelectionColour, 0.04);
	}
	N = 0;
	for (const MBPaint::FCell& C : Preview)
	{
		if (++N > MaxDrawn) break;
		DrawCell(C, PreviewColour, 0.02);
	}
}

#undef LOCTEXT_NAMESPACE
