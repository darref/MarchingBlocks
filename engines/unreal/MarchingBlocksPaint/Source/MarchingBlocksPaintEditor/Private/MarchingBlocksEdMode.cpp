// MarchingBlocks Paint for Unreal — the editor mode (see MarchingBlocksEdMode.h).

#include "MarchingBlocksEdMode.h"

#include "MarchingBlocksModeToolkit.h"
#include "EditorViewportClient.h"
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

// The Rect ignores the aim: it always lies flat on the floor — the gesture that draws a room's floor.
bool UMarchingBlocksEdMode::BoxCorner(AMarchingBlocksWorld* World, const FVector& Origin, const FVector& Direction, MBPaint::FCell& Corner)
{
	if (World->Tool == EMarchingBlocksTool::Rect) return World->CellUnderRay(Origin, Direction, Corner);
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
		const MBPaint::FCellSet& Full = World->GetCells();
		for (const MBPaint::FCell& C : Cells)
		{
			if (bDeselect) World->Selection.erase(C);
			else if (Full.count(C)) World->Selection.insert(C);
		}
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
		const MBPaint::FCell Anchor = MBPaint::Tools::Anchor(MBPaint::EBrushTool::Add, Hit);
		for (const MBPaint::FCell& D : World->Clipboard) Preview.push_back(Anchor + D);
		PreviewColour = AddColour;
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
					const MBPaint::FChange Change = MBPaint::Tools::Paste(World->GetCells(), World->Clipboard,
						MBPaint::Tools::Anchor(MBPaint::EBrushTool::Add, Hit));
					World->Apply(Change);
					World->Selection = Change.Selection;
					World->bPasting = false;
				}
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

	if (Event != IE_Pressed || bFlying) return false;
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
	if (Key == EKeys::A) World->Tool = EMarchingBlocksTool::Add;
	else if (Key == EKeys::D) World->Tool = EMarchingBlocksTool::Dig;
	else if (Key == EKeys::S) World->Tool = EMarchingBlocksTool::Select;
	else if (Key == EKeys::G) World->Tool = EMarchingBlocksTool::Rect;
	else if (Key == EKeys::B) World->Tool = EMarchingBlocksTool::Box;
	else if (Key == EKeys::Tab) SetAimState(World, MBPaint::Tools::Tab(World->GetAimState()));
	else if (Key == EKeys::SpaceBar) SetAimState(World, MBPaint::Tools::ToggleNavigate(World->GetAimState()));
	else if (Key == EKeys::LeftBracket) World->BrushSize = FMath::Max(1, World->BrushSize - 1);
	else if (Key == EKeys::RightBracket) World->BrushSize = FMath::Min(7, World->BrushSize + 1);
	else if (Key == EKeys::PageUp || Key == EKeys::PageDown)
	{
		const FScopedTransaction Transaction(LOCTEXT("Floor", "Change floor"));
		World->Modify();
		World->Floor += Key == EKeys::PageUp ? 1 : -1;
	}
	else if (Key == EKeys::Delete) World->DeleteSelected();
	else if (Key == EKeys::Escape)
	{
		if (World->bPasting || bBoxing) { World->bPasting = false; bBoxing = false; }
		else World->ClearSelection();
	}
	else return false;
	Preview.clear();
	return true;
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
