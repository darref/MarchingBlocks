// MarchingBlocks Paint for Unreal — the mode panel (see MarchingBlocksModeToolkit.h).

#include "MarchingBlocksModeToolkit.h"

#include "MarchingBlocksEdMode.h"
#include "MarchingBlocksWorld.h"
#include "ScopedTransaction.h"
#include "Styling/AppStyle.h"
#include "Styling/SlateStyleRegistry.h"
#include "Widgets/Images/SImage.h"
#include "Widgets/Input/SButton.h"
#include "Widgets/Input/SCheckBox.h"
#include "Widgets/Input/SSpinBox.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/Layout/SWrapBox.h"
#include "Widgets/SBoxPanel.h"
#include "Widgets/Text/STextBlock.h"

#define LOCTEXT_NAMESPACE "MarchingBlocksModeToolkit"

const FName FMarchingBlocksModeToolkit::StyleName(TEXT("MarchingBlocksPaintStyle"));

// ⚠ A NAMED namespace, never an anonymous one or file statics: Unreal's "unity builds" paste several .cpp
// files together, and two helpers of the same name would collide.
namespace MarchingBlocksToolkitDetail
{
	const FLinearColor Olive(0.706f, 0.741f, 0.522f);
	const FLinearColor Red(0.878f, 0.376f, 0.235f);
	const FLinearColor Grey(0.55f, 0.57f, 0.55f);
	const FVector2D IconSize(18.0, 18.0);

	const FSlateBrush* Icon(const ANSICHAR* Name)
	{
		const ISlateStyle* Style = FSlateStyleRegistry::FindSlateStyle(FMarchingBlocksModeToolkit::StyleName);
		return Style ? Style->GetBrush(FName(FString(TEXT("MarchingBlocks.")) + ANSI_TO_TCHAR(Name))) : FAppStyle::GetNoBrush();
	}

	TSharedRef<SWidget> Title(const FText& Text)
	{
		return SNew(SBox).Padding(FMargin(0.f, 8.f, 0.f, 3.f))
		[
			SNew(STextBlock).Text(Text).Font(FAppStyle::GetFontStyle("SmallFontBold")).ColorAndOpacity(FSlateColor(Grey))
		];
	}

	/** An icon toggle: the tooltip names it and gives its key. Down, its icon turns olive — the tool's accent. */
	TSharedRef<SWidget> Toggle(const ANSICHAR* IconName, const FText& Tip, TFunction<bool()> IsOn, TFunction<void()> Act)
	{
		return SNew(SBox).Padding(FMargin(0.f, 0.f, 2.f, 0.f))
		[
			SNew(SCheckBox)
			.Style(&FAppStyle::Get().GetWidgetStyle<FCheckBoxStyle>("ToggleButtonCheckbox"))
			.ToolTipText(Tip)
			.Padding(FMargin(5.f, 3.f))
			.IsChecked_Lambda([IsOn]() { return IsOn() ? ECheckBoxState::Checked : ECheckBoxState::Unchecked; })
			.OnCheckStateChanged_Lambda([Act](ECheckBoxState) { Act(); })
			[
				SNew(SImage).Image(Icon(IconName)).DesiredSizeOverride(IconSize)
				.ColorAndOpacity_Lambda([IsOn]() { return IsOn() ? FSlateColor(Olive) : FSlateColor::UseForeground(); })
			]
		];
	}

	TSharedRef<SWidget> Button(const ANSICHAR* IconName, const FText& Tip, TFunction<void()> Act, bool bDanger = false)
	{
		return SNew(SBox).Padding(FMargin(0.f, 0.f, 2.f, 0.f))
		[
			SNew(SButton)
			.ButtonStyle(FAppStyle::Get(), "SimpleButton")
			.ToolTipText(Tip)
			.ContentPadding(FMargin(5.f, 3.f))
			.OnClicked_Lambda([Act]() { Act(); return FReply::Handled(); })
			[
				SNew(SImage).Image(Icon(IconName)).DesiredSizeOverride(IconSize)
				.ColorAndOpacity(bDanger ? FSlateColor(Red) : FSlateColor::UseForeground())
			]
		];
	}

	TSharedRef<SWidget> Gap() { return SNew(SBox).WidthOverride(8.f); }
}

FText FMarchingBlocksModeToolkit::GetBaseToolkitName() const
{
	return LOCTEXT("Name", "MarchingBlocks");
}

void FMarchingBlocksModeToolkit::Init(const TSharedPtr<IToolkitHost>& InitToolkitHost, TWeakObjectPtr<UEdMode> InOwningMode)
{
	Mode = Cast<UMarchingBlocksEdMode>(InOwningMode.Get());
	Panel = BuildPanel();
	FModeToolkit::Init(InitToolkitHost, InOwningMode);
}

TSharedRef<SWidget> FMarchingBlocksModeToolkit::BuildPanel()
{
	using namespace MarchingBlocksToolkitDetail;
	TWeakObjectPtr<UMarchingBlocksEdMode> M = Mode;
	// Every widget reads the SELECTED world when it draws: selecting another one needs no rebuild.
	auto World = [M]() -> AMarchingBlocksWorld* { return M.IsValid() ? M->Target() : nullptr; };
	auto Has = [World]() { return World() != nullptr; };
	auto Shown = [](bool b) { return b ? EVisibility::Visible : EVisibility::Collapsed; };

	auto AimToggle = [World, M](const ANSICHAR* IconName, const FText& Tip, EMarchingBlocksAim Aim)
	{
		return Toggle(IconName, Tip,
			[World, Aim]() { AMarchingBlocksWorld* W = World(); return W && !W->GetAimState().bNavigating && W->Aim == Aim; },
			[World, M, Aim]()
			{
				AMarchingBlocksWorld* W = World();
				if (W && M.IsValid())
					M->SetAimState(W, MBPaint::Tools::ChooseAim(W->GetAimState(),
						Aim == EMarchingBlocksAim::Sculpt ? MBPaint::EAim::Sculpt : MBPaint::EAim::Grid));
			});
	};
	auto ToolToggle = [World](const ANSICHAR* IconName, const FText& Tip, EMarchingBlocksTool Tool)
	{
		return Toggle(IconName, Tip, [World, Tool]() { AMarchingBlocksWorld* W = World(); return W && W->Tool == Tool; },
			[World, Tool]() { if (AMarchingBlocksWorld* W = World()) { W->Tool = Tool; W->bPasting = false; } });
	};
	auto ShapeToggle = [World](const ANSICHAR* IconName, const FText& Tip, EMarchingBlocksBrushShape Shape)
	{
		return Toggle(IconName, Tip, [World, Shape]() { AMarchingBlocksWorld* W = World(); return W && W->BrushShape == Shape; },
			[World, Shape]() { if (AMarchingBlocksWorld* W = World()) W->BrushShape = Shape; });
	};
	// A special shape: the tool becomes Shape, and a first end of a Connect is forgotten.
	auto SpecialToggle = [World, M](const ANSICHAR* IconName, const FText& Tip, EMarchingBlocksSpecialShape Special)
	{
		return Toggle(IconName, Tip,
			[World, Special]() { AMarchingBlocksWorld* W = World(); return W && W->Tool == EMarchingBlocksTool::Shape && W->SpecialShape == Special; },
			[World, M, Special]()
			{
				if (AMarchingBlocksWorld* W = World())
				{
					W->Tool = EMarchingBlocksTool::Shape;
					W->SpecialShape = Special;
					W->bPasting = false;
					if (M.IsValid()) M->ForgetShapeAnchor();
				}
			});
	};
	auto EndsToggle = [World, M](const ANSICHAR* IconName, const FText& Tip, bool bConnect)
	{
		return Toggle(IconName, Tip, [World, bConnect]() { AMarchingBlocksWorld* W = World(); return W && W->bConnectEnds == bConnect; },
			[World, M, bConnect]()
			{
				if (AMarchingBlocksWorld* W = World()) W->bConnectEnds = bConnect;
				if (M.IsValid()) M->ForgetShapeAnchor();
			});
	};
	auto ProfileToggle = [World](const ANSICHAR* IconName, const FText& Tip, EMarchingBlocksShapeProfile Profile)
	{
		return Toggle(IconName, Tip, [World, Profile]() { AMarchingBlocksWorld* W = World(); return W && W->ShapeProfile == Profile; },
			[World, Profile]() { if (AMarchingBlocksWorld* W = World()) W->ShapeProfile = Profile; });
	};
	auto Shaping = [World]() { AMarchingBlocksWorld* W = World(); return W && W->Tool == EMarchingBlocksTool::Shape; };
	auto Op = [World](const ANSICHAR* IconName, const FText& Tip, void (AMarchingBlocksWorld::*Fn)(), bool bDanger = false)
	{
		return Button(IconName, Tip, [World, Fn]() { if (AMarchingBlocksWorld* W = World()) (W->*Fn)(); }, bDanger);
	};
	auto SetFloor = [World](int32 Floor)
	{
		AMarchingBlocksWorld* W = World();
		if (!W || W->Floor == Floor) return;
		const FScopedTransaction Transaction(LOCTEXT("Floor", "Change floor"));
		W->Modify();
		W->Floor = Floor;
	};
	auto Move = [World](const TCHAR* Label, MBPaint::FCell Offset)
	{
		return SNew(SBox).Padding(FMargin(0.f, 0.f, 2.f, 0.f))
		[
			SNew(SButton)
			.ButtonStyle(FAppStyle::Get(), "SimpleButton")
			.ToolTipText(FText::Format(LOCTEXT("MoveTip", "Moves the selected matter one cell ({0}). The arrow keys "
				"move it too, following the camera; Shift + up / down lift."), FText::FromString(Label)))
			.ContentPadding(FMargin(5.f, 3.f))
			.OnClicked_Lambda([World, Offset]() { if (AMarchingBlocksWorld* W = World()) W->MoveSelection(Offset); return FReply::Handled(); })
			[
				SNew(STextBlock).Text(FText::FromString(Label)).Font(FAppStyle::GetFontStyle("SmallFontBold"))
			]
		];
	};

	return SNew(SBox).Padding(FMargin(8.f, 6.f))
	[
		SNew(SVerticalBox)

		// Which world the panel drives — or how to get one.
		+ SVerticalBox::Slot().AutoHeight()
		[
			SNew(STextBlock).AutoWrapText(true)
			.Text_Lambda([World]()
			{
				AMarchingBlocksWorld* W = World();
				return W ? FText::FromString(W->GetActorLabel())
					: LOCTEXT("NoWorld", "Select a MarchingBlocks World in the level to paint it.");
			})
			.ColorAndOpacity_Lambda([Has]() { return Has() ? FSlateColor(Olive) : FSlateColor::UseSubduedForeground(); })
			.Font_Lambda([Has]() { return Has() ? FAppStyle::GetFontStyle("BoldFont") : FAppStyle::GetFontStyle("NormalFont"); })
		]

		+ SVerticalBox::Slot().AutoHeight()
		[
			SNew(SVerticalBox)
			.Visibility_Lambda([Has, Shown]() { return Shown(Has()); })

			+ SVerticalBox::Slot().AutoHeight()[Title(LOCTEXT("Aim", "AIM · Tab          NAVIGATE · Space"))]
			+ SVerticalBox::Slot().AutoHeight()
			[
				SNew(SHorizontalBox)
				+ SHorizontalBox::Slot().AutoWidth()[AimToggle("grid", LOCTEXT("Grid", "Grid (Tab) — aims at the floor plane. Page Up / Page Down move it."), EMarchingBlocksAim::Grid)]
				+ SHorizontalBox::Slot().AutoWidth()[AimToggle("sculpt", LOCTEXT("Sculpt", "Sculpt (Tab) — aims at the matter itself: Add builds against the face you point at."), EMarchingBlocksAim::Sculpt)]
				+ SHorizontalBox::Slot().AutoWidth()[Gap()]
				+ SHorizontalBox::Slot().AutoWidth()
				[
					Toggle("navigate", LOCTEXT("Navigate", "Navigate (Space) — the viewport flies as usual, no click paints. "
						"Space again comes back to the same aim."),
						[World]() { AMarchingBlocksWorld* W = World(); return W && W->GetAimState().bNavigating; },
						[World, M]()
						{
							AMarchingBlocksWorld* W = World();
							if (W && M.IsValid()) M->SetAimState(W, MBPaint::Tools::ToggleNavigate(W->GetAimState()));
						})
				]
			]

			+ SVerticalBox::Slot().AutoHeight()[Title(LOCTEXT("Tool", "TOOL"))]
			+ SVerticalBox::Slot().AutoHeight()
			[
				SNew(SHorizontalBox)
				+ SHorizontalBox::Slot().AutoWidth()[ToolToggle("add", LOCTEXT("Add", "Add (A) — adds matter. Shift digs."), EMarchingBlocksTool::Add)]
				+ SHorizontalBox::Slot().AutoWidth()[ToolToggle("dig", LOCTEXT("Dig", "Dig (D) — removes matter. Shift adds."), EMarchingBlocksTool::Dig)]
				+ SHorizontalBox::Slot().AutoWidth()[ToolToggle("select", LOCTEXT("Select", "Select (S) — paints the selection over the matter. Shift adds, Ctrl removes."), EMarchingBlocksTool::Select)]
				+ SHorizontalBox::Slot().AutoWidth()[ToolToggle("rect", LOCTEXT("Rect", "Rect (G) — a FLAT rectangle on the floor, whatever the aim, empty cells included: a room's floor."), EMarchingBlocksTool::Rect)]
				+ SHorizontalBox::Slot().AutoWidth()[ToolToggle("box", LOCTEXT("Box", "Box (B) — a 3D box: the whole volume, empty cells included. Shift adds, Ctrl removes."), EMarchingBlocksTool::Box)]
				+ SHorizontalBox::Slot().AutoWidth()[Gap()]
				+ SHorizontalBox::Slot().AutoWidth()
				[
					SNew(SBox).Visibility_Lambda([World, Shown]() { AMarchingBlocksWorld* W = World(); return Shown(W && W->Tool == EMarchingBlocksTool::Box); })
					[
						Toggle("hollow", LOCTEXT("Hollow", "Hollow box — keeps the skin: a room. A box thinner than three cells stays solid."),
							[World]() { AMarchingBlocksWorld* W = World(); return W && W->bHollowBox; },
							[World]() { if (AMarchingBlocksWorld* W = World()) W->bHollowBox = !W->bHollowBox; })
					]
				]
			]

			// The special shapes: a tool of their own, always aimed at the matter; their settings only while it is
			// the tool, and only what the shape reads.
			+ SVerticalBox::Slot().AutoHeight()[Title(LOCTEXT("Shapes", "SPECIAL SHAPES"))]
			+ SVerticalBox::Slot().AutoHeight()
			[
				SNew(SHorizontalBox)
				+ SHorizontalBox::Slot().AutoWidth()[SpecialToggle("tunnel", LOCTEXT("Tunnel", "Tunnel — digs into a WALL, square to it: one click goes through to the next cave (or Shape Length deep); Connect joins two walls anywhere, slanted ones included."), EMarchingBlocksSpecialShape::Tunnel)]
				+ SHorizontalBox::Slot().AutoWidth()[SpecialToggle("well", LOCTEXT("Well", "Well — digs into a FLOOR or a CEILING, straight: one click stops in the cave below (or Shape Length deep); Connect joins a floor and a ceiling."), EMarchingBlocksSpecialShape::Well)]
				+ SHorizontalBox::Slot().AutoWidth()[SpecialToggle("bridge", LOCTEXT("Bridge", "Bridge — a deck out of a WALL across the air to the first wall in front; Connect joins two walls, and the deck bends."), EMarchingBlocksSpecialShape::Bridge)]
				+ SHorizontalBox::Slot().AutoWidth()[SpecialToggle("balcony", LOCTEXT("Balcony", "Balcony — a slab sticking out of a WALL at the height you click, with its rail."), EMarchingBlocksSpecialShape::Balcony)]
				+ SHorizontalBox::Slot().AutoWidth()[SpecialToggle("stairs", LOCTEXT("Stairs", "Stairs — click a WALL where they should arrive: they come down to the ground, Step cells per step; Connect climbs from one floor to another, higher up."), EMarchingBlocksSpecialShape::Stairs)]
			]
			+ SVerticalBox::Slot().AutoHeight()
			[
				SNew(SVerticalBox)
				.Visibility_Lambda([Shaping, Shown]() { return Shown(Shaping()); })
				+ SVerticalBox::Slot().AutoHeight().Padding(FMargin(0.f, 3.f, 0.f, 0.f))
				[
					SNew(SHorizontalBox)
					+ SHorizontalBox::Slot().AutoWidth()
					[
						SNew(SHorizontalBox)
						.Visibility_Lambda([World, Shown]() { AMarchingBlocksWorld* W = World(); return Shown(W && W->SpecialShape != EMarchingBlocksSpecialShape::Balcony); })
						+ SHorizontalBox::Slot().AutoWidth()[EndsToggle("straight", LOCTEXT("Straight", "Straight — one click: straight out of the face, square to it."), false)]
						+ SHorizontalBox::Slot().AutoWidth()[EndsToggle("connect", LOCTEXT("Connect", "Connect — two clicks: a face, then another one; both ends stay open. Esc forgets the first."), true)]
						+ SHorizontalBox::Slot().AutoWidth()[Gap()]
					]
					+ SHorizontalBox::Slot().AutoWidth()
					[
						SNew(SHorizontalBox)
						.Visibility_Lambda([World, Shown]()
						{
							AMarchingBlocksWorld* W = World();
							return Shown(W && (W->SpecialShape == EMarchingBlocksSpecialShape::Tunnel || W->SpecialShape == EMarchingBlocksSpecialShape::Well));
						})
						+ SHorizontalBox::Slot().AutoWidth()[ProfileToggle("round", LOCTEXT("Round", "Round — a round tube."), EMarchingBlocksShapeProfile::Round)]
						+ SHorizontalBox::Slot().AutoWidth()[ProfileToggle("square", LOCTEXT("Square", "Square — a square duct."), EMarchingBlocksShapeProfile::Square)]
						+ SHorizontalBox::Slot().AutoWidth()[ProfileToggle("arch", LOCTEXT("Arch", "Arch — a flat floor and a round vault: a corridor you can walk."), EMarchingBlocksShapeProfile::Arch)]
					]
					+ SHorizontalBox::Slot().AutoWidth()
					[
						SNew(SBox)
						.Visibility_Lambda([World, Shown]()
						{
							AMarchingBlocksWorld* W = World();
							return Shown(W && (W->SpecialShape == EMarchingBlocksSpecialShape::Bridge || W->SpecialShape == EMarchingBlocksSpecialShape::Balcony
								|| W->SpecialShape == EMarchingBlocksSpecialShape::Stairs));
						})
						[
							Toggle("rail", LOCTEXT("Rail", "Rail — a one-cell rim along the open sides. Needs a size of 2 or more."),
								[World]() { AMarchingBlocksWorld* W = World(); return W && W->bShapeRail; },
								[World]() { if (AMarchingBlocksWorld* W = World()) W->bShapeRail = !W->bShapeRail; })
						]
					]
				]
				+ SVerticalBox::Slot().AutoHeight().Padding(FMargin(0.f, 3.f, 0.f, 0.f))
				[
					SNew(SHorizontalBox)
					+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center).Padding(FMargin(0.f, 0.f, 6.f, 0.f))
					[
						SNew(STextBlock).Text(LOCTEXT("ShapeSize", "Size")).Font(FAppStyle::GetFontStyle("SmallFont"))
					]
					+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center)
					[
						SNew(SBox).WidthOverride(64.f)
						[
							SNew(SSpinBox<int32>).MinValue(1).MaxValue(7).MinSliderValue(1).MaxSliderValue(7)
							.ToolTipText(LOCTEXT("ShapeSizeTip", "[ and ] — 1 is one cell across, 2 is three, 3 is five…"))
							.Value_Lambda([World]() { AMarchingBlocksWorld* W = World(); return W ? W->ShapeSize : 2; })
							.OnValueChanged_Lambda([World](int32 V) { if (AMarchingBlocksWorld* W = World()) W->ShapeSize = FMath::Clamp(V, 1, 7); })
						]
					]
					+ SHorizontalBox::Slot().AutoWidth()[Gap()]
					+ SHorizontalBox::Slot().AutoWidth()
					[
						SNew(SHorizontalBox)
						.Visibility_Lambda([World, Shown]()
						{
							AMarchingBlocksWorld* W = World();
							return Shown(W && (W->SpecialShape == EMarchingBlocksSpecialShape::Balcony || !W->bConnectEnds));
						})
						+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center).Padding(FMargin(0.f, 0.f, 6.f, 0.f))
						[
							SNew(STextBlock).Text(LOCTEXT("ShapeLength", "Length")).Font(FAppStyle::GetFontStyle("SmallFont"))
						]
						+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center)
						[
							SNew(SBox).WidthOverride(64.f)
							[
								SNew(SSpinBox<int32>).MinValue(1).MaxValue(64).MinSliderValue(1).MaxSliderValue(64)
								.ToolTipText(LOCTEXT("ShapeLengthTip", "How deep a straight tunnel or well goes when it finds no cave, how far a straight bridge looks for a wall, how far a balcony sticks out, how far stairs may run before they reach the ground."))
								.Value_Lambda([World]() { AMarchingBlocksWorld* W = World(); return W ? W->ShapeLength : 8; })
								.OnValueChanged_Lambda([World](int32 V) { if (AMarchingBlocksWorld* W = World()) W->ShapeLength = FMath::Clamp(V, 1, 64); })
							]
						]
					]
					+ SHorizontalBox::Slot().AutoWidth()[Gap()]
					+ SHorizontalBox::Slot().AutoWidth()
					[
						SNew(SHorizontalBox)
						.Visibility_Lambda([World, Shown]()
						{
							AMarchingBlocksWorld* W = World();
							return Shown(W && W->SpecialShape == EMarchingBlocksSpecialShape::Stairs && !W->bConnectEnds);
						})
						+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center).Padding(FMargin(0.f, 0.f, 6.f, 0.f))
						[
							SNew(STextBlock).Text(LOCTEXT("StairsStep", "Step")).Font(FAppStyle::GetFontStyle("SmallFont"))
						]
						+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center)
						[
							SNew(SBox).WidthOverride(48.f)
							[
								SNew(SSpinBox<int32>).MinValue(1).MaxValue(4).MinSliderValue(1).MaxSliderValue(4)
								.ToolTipText(LOCTEXT("StairsStepTip", "How deep each stair is, in cells (1 is steep)."))
								.Value_Lambda([World]() { AMarchingBlocksWorld* W = World(); return W ? W->StairsStep : 2; })
								.OnValueChanged_Lambda([World](int32 V) { if (AMarchingBlocksWorld* W = World()) W->StairsStep = FMath::Clamp(V, 1, 4); })
							]
						]
					]
				]
			]

			// The brush: only for Add, Dig and Select — Rect and Box have none.
			+ SVerticalBox::Slot().AutoHeight()
			[
				SNew(SVerticalBox)
				.Visibility_Lambda([World, Shown]()
				{
					AMarchingBlocksWorld* W = World();
					return Shown(W && (W->Tool == EMarchingBlocksTool::Add || W->Tool == EMarchingBlocksTool::Dig || W->Tool == EMarchingBlocksTool::Select));
				})
				+ SVerticalBox::Slot().AutoHeight()[Title(LOCTEXT("Brush", "BRUSH · [ ]"))]
				+ SVerticalBox::Slot().AutoHeight()
				[
					SNew(SHorizontalBox)
					+ SHorizontalBox::Slot().AutoWidth()[ShapeToggle("sphere", LOCTEXT("Sphere", "Sphere — a ball of cells."), EMarchingBlocksBrushShape::Sphere)]
					+ SHorizontalBox::Slot().AutoWidth()[ShapeToggle("cube", LOCTEXT("Cube", "Cube — a cube of cells."), EMarchingBlocksBrushShape::Cube)]
					+ SHorizontalBox::Slot().AutoWidth()[ShapeToggle("disc", LOCTEXT("Disc", "Disc — flat, across the face you point at: fills or digs a wall without thickening it."), EMarchingBlocksBrushShape::Disc)]
					+ SHorizontalBox::Slot().AutoWidth()[Gap()]
					+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center)
					[
						SNew(SBox).WidthOverride(64.f)
						[
							SNew(SSpinBox<int32>).MinValue(1).MaxValue(7).MinSliderValue(1).MaxSliderValue(7)
							.ToolTipText(LOCTEXT("Size", "Brush size ( [ and ] ). 1 is a single cell."))
							.Value_Lambda([World]() { AMarchingBlocksWorld* W = World(); return W ? W->BrushSize : 1; })
							.OnValueChanged_Lambda([World](int32 V) { if (AMarchingBlocksWorld* W = World()) W->BrushSize = FMath::Clamp(V, 1, 7); })
						]
					]
				]
			]

			+ SVerticalBox::Slot().AutoHeight()[Title(LOCTEXT("FloorTitle", "FLOOR · PgUp PgDn"))]
			+ SVerticalBox::Slot().AutoHeight()
			[
				SNew(SHorizontalBox)
				+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center).Padding(FMargin(0.f, 0.f, 6.f, 0.f))
				[
					SNew(SImage).Image(Icon("floor")).DesiredSizeOverride(IconSize).ColorAndOpacity(FSlateColor::UseSubduedForeground())
					.ToolTipText(LOCTEXT("FloorTip", "The plane the Grid aim and the Rect paint on."))
				]
				+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center)
				[
					SNew(SBox).WidthOverride(64.f)
					[
						SNew(SSpinBox<int32>).MinValue(-4096).MaxValue(4096).Delta(1)
						.Value_Lambda([World]() { AMarchingBlocksWorld* W = World(); return W ? W->Floor : 0; })
						.OnValueCommitted_Lambda([SetFloor](int32 V, ETextCommit::Type) { SetFloor(V); })
					]
				]
				+ SHorizontalBox::Slot().AutoWidth()[Gap()]
				+ SHorizontalBox::Slot().AutoWidth()[Button("down", LOCTEXT("FloorDown", "Page Down — one floor lower."), [World, SetFloor]() { if (AMarchingBlocksWorld* W = World()) SetFloor(W->Floor - 1); })]
				+ SHorizontalBox::Slot().AutoWidth()[Button("up", LOCTEXT("FloorUp", "Page Up — one floor higher."), [World, SetFloor]() { if (AMarchingBlocksWorld* W = World()) SetFloor(W->Floor + 1); })]
			]

			// The selection: its operations appear once there is something selected, as in the tool.
			+ SVerticalBox::Slot().AutoHeight()
			[
				SNew(SVerticalBox)
				.Visibility_Lambda([World, Shown]() { AMarchingBlocksWorld* W = World(); return Shown(W && !W->Selection.empty()); })
				+ SVerticalBox::Slot().AutoHeight()
				[
					SNew(SBox).Padding(FMargin(0.f, 8.f, 0.f, 3.f))
					[
						SNew(STextBlock).Font(FAppStyle::GetFontStyle("SmallFontBold")).ColorAndOpacity(FSlateColor(Grey))
						.Text_Lambda([World]()
						{
							AMarchingBlocksWorld* W = World();
							return FText::Format(LOCTEXT("Selection", "SELECTION · {0} cells"), W ? static_cast<int32>(W->Selection.size()) : 0);
						})
					]
				]
				+ SVerticalBox::Slot().AutoHeight()
				[
					SNew(SWrapBox).UseAllottedSize(true)
					+ SWrapBox::Slot()[Op("fill", LOCTEXT("Fill", "Fill — fills every selected cell with matter. Draw a Rect or a Box, then Fill it."), &AMarchingBlocksWorld::Fill)]
					+ SWrapBox::Slot()[Op("delete", LOCTEXT("Delete", "Delete (Del) — removes the selected matter."), &AMarchingBlocksWorld::DeleteSelected, true)]
					+ SWrapBox::Slot()[Op("clear", LOCTEXT("Clear", "Clear (Esc) — forgets the selection. No cell changes."), &AMarchingBlocksWorld::ClearSelection)]
					+ SWrapBox::Slot()[Gap()]
					+ SWrapBox::Slot()[Op("extrude_up", LOCTEXT("ExtrudeUp", "Extrude up — adds the layer above; the selection AND the floor follow it."), &AMarchingBlocksWorld::ExtrudeUp)]
					+ SWrapBox::Slot()[Op("extrude_down", LOCTEXT("ExtrudeDown", "Extrude down — adds the layer below; the selection and the floor follow it."), &AMarchingBlocksWorld::ExtrudeDown)]
					+ SWrapBox::Slot()[Gap()]
					+ SWrapBox::Slot()[Op("grow", LOCTEXT("Grow", "Grow — selects the matter touching the selection by a face."), &AMarchingBlocksWorld::Grow)]
					+ SWrapBox::Slot()[Op("shrink", LOCTEXT("Shrink", "Shrink — drops the selected cells that touch an unselected one."), &AMarchingBlocksWorld::Shrink)]
					+ SWrapBox::Slot()[Op("connected", LOCTEXT("Connected", "Connected — selects all the matter linked to the selection by faces."), &AMarchingBlocksWorld::SelectConnected)]
				]
				+ SVerticalBox::Slot().AutoHeight().Padding(FMargin(0.f, 2.f, 0.f, 0.f))
				[
					SNew(SWrapBox).UseAllottedSize(true)
					+ SWrapBox::Slot()[Move(TEXT("−X"), MBPaint::FCell(-1, 0, 0))]
					+ SWrapBox::Slot()[Move(TEXT("+X"), MBPaint::FCell(1, 0, 0))]
					+ SWrapBox::Slot()[Move(TEXT("−Y"), MBPaint::FCell(0, -1, 0))]
					+ SWrapBox::Slot()[Move(TEXT("+Y"), MBPaint::FCell(0, 1, 0))]
					+ SWrapBox::Slot()[Move(TEXT("−Z"), MBPaint::FCell(0, 0, -1))]
					+ SWrapBox::Slot()[Move(TEXT("+Z"), MBPaint::FCell(0, 0, 1))]
					+ SWrapBox::Slot()[Gap()]
					+ SWrapBox::Slot()[Op("copy", LOCTEXT("Copy", "Copy (Ctrl+C) — copies the selected matter."), &AMarchingBlocksWorld::CopySelection)]
					+ SWrapBox::Slot()[Op("cut", LOCTEXT("Cut", "Cut (Ctrl+X) — copies, then deletes."), &AMarchingBlocksWorld::CutSelection)]
				]
			]

			// Paste stays while the clipboard holds something, selection or not.
			+ SVerticalBox::Slot().AutoHeight()
			[
				SNew(SVerticalBox)
				.Visibility_Lambda([World, Shown]() { AMarchingBlocksWorld* W = World(); return Shown(W && !W->Clipboard.empty()); })
				+ SVerticalBox::Slot().AutoHeight()[Title(LOCTEXT("Clipboard", "CLIPBOARD · Ctrl V"))]
				+ SVerticalBox::Slot().AutoHeight()
				[
					SNew(SHorizontalBox)
					+ SHorizontalBox::Slot().AutoWidth()
					[
						Toggle("paste", LOCTEXT("Paste", "Paste (Ctrl+V) — the copy follows the mouse; click in the viewport to place it, Esc cancels."),
							[World]() { AMarchingBlocksWorld* W = World(); return W && W->bPasting; },
							[World]() { if (AMarchingBlocksWorld* W = World()) { if (W->bPasting) W->bPasting = false; else W->PasteClipboard(); } })
					]
					+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center).Padding(FMargin(6.f, 0.f, 0.f, 0.f))
					[
						SNew(STextBlock).Font(FAppStyle::GetFontStyle("SmallFont"))
						.Text_Lambda([World]()
						{
							AMarchingBlocksWorld* W = World();
							if (W && W->bPasting) return LOCTEXT("Pasting", "Click in the viewport — Esc cancels");
							return FText::Format(LOCTEXT("Copied", "{0} cells copied"), W ? static_cast<int32>(W->Clipboard.size()) : 0);
						})
					]
				]
			]

			+ SVerticalBox::Slot().AutoHeight()[Title(LOCTEXT("Layer", "LAYER"))]
			+ SVerticalBox::Slot().AutoHeight()
			[
				SNew(SHorizontalBox)
				+ SHorizontalBox::Slot().AutoWidth()[Op("world", LOCTEXT("Rebuild", "Rebuild — lays the tiles again from the cells."), &AMarchingBlocksWorld::Rebuild)]
				+ SHorizontalBox::Slot().AutoWidth()[Op("erase", LOCTEXT("ClearCells", "Clear cells — erases every cell of this layer (Ctrl+Z brings them back)."), &AMarchingBlocksWorld::ClearCells, true)]
			]

			// What happened last: tiles placed, missing ones, an error.
			+ SVerticalBox::Slot().AutoHeight().Padding(FMargin(0.f, 8.f, 0.f, 0.f))
			[
				SNew(STextBlock).AutoWrapText(true).Font(FAppStyle::GetFontStyle("SmallFont"))
				.Text_Lambda([World]() { AMarchingBlocksWorld* W = World(); return W ? FText::FromString(W->Status) : FText::GetEmpty(); })
				.ColorAndOpacity_Lambda([World]()
				{
					AMarchingBlocksWorld* W = World();
					return W && W->Status.Contains(TEXT("missing")) ? FSlateColor(Red) : FSlateColor(Olive);
				})
			]
		]
	];
}

#undef LOCTEXT_NAMESPACE
