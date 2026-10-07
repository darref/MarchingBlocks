// MarchingBlocks Paint for Unreal — the world layer actor (see MarchingBlocksWorld.h).

#include "MarchingBlocksWorld.h"

#include "MarchingBlocksTransitions.h"
#include "MarchingBlocksWater.h"
#include "MBCore/MBAnimation.h"
#include "Engine/Texture.h"
#include "Engine/Texture2DArray.h"
#include "Materials/MaterialInterface.h"

#include "Components/InstancedStaticMeshComponent.h"
#include "EngineUtils.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "StaticMeshResources.h"

#if WITH_EDITOR
#include "AssetRegistry/AssetRegistryModule.h"
#include "ScopedTransaction.h"
#endif

// ⚠ ALL THE FRAME MATHS IS IN MBCore/MBFrame (standard C++, proven by core-runner on a mirrored,
// centimetre frame). This file only converts between FVector and FVec3: a second copy of the maths here
// would be a second description, and it would drift.
namespace MarchingBlocksWorldDetail
{
	MBPaint::FCell ToCell(const FIntVector& V) { return MBPaint::FCell(V.X, V.Y, V.Z); }
	MBPaint::FVec3 ToVec3(const FVector& V) { return MBPaint::FVec3(V.X, V.Y, V.Z); }
	FVector ToFVector(const MBPaint::FVec3& V) { return FVector(V.X, V.Y, V.Z); }
}

MBPaint::FFrame AMarchingBlocksWorld::Frame() const
{
	MBPaint::FFrame F;
	F.AxisX = MarchingBlocksWorldDetail::ToVec3(FrameX);
	F.AxisY = MarchingBlocksWorldDetail::ToVec3(FrameY);
	F.AxisZ = MarchingBlocksWorldDetail::ToVec3(FrameZ);
	F.Unit = FrameUnit;
	return F;
}

AMarchingBlocksWorld::AMarchingBlocksWorld()
{
	PrimaryActorTick.bCanEverTick = false;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

const MBPaint::FCellSet& AMarchingBlocksWorld::GetCells()
{
	if (!bIndexValid || Index.size() != static_cast<size_t>(Cells.Num()))
	{
		Index.clear();
		for (const FIntVector& C : Cells) Index.insert(MarchingBlocksWorldDetail::ToCell(C));
		bIndexValid = true;
	}
	return Index;
}

int32 AMarchingBlocksWorld::Apply(const MBPaint::FChange& Change)
{
	GetCells();
	int32 N = 0;
	for (const MBPaint::FCell& C : Change.Clear) N += static_cast<int32>(Index.erase(C));
	for (const MBPaint::FCell& C : Change.Set) N += Index.insert(C).second ? 1 : 0;
	// A CELL BELONGS TO ONE LAYER: what this change sets leaves the other layers of the world (recorded in the
	// same transaction, so one undo gives it back).
	for (AMarchingBlocksWorld* Other : GetLayers())
	{
		if (Other == this) continue;
		Other->GetCells();
		bool bTouched = false;
		for (const MBPaint::FCell& C : Change.Set)
			if (Other->Index.count(C))
			{
				if (!bTouched) { Other->Modify(); bTouched = true; }
				Other->Index.erase(C);
				++N;
			}
		if (bTouched)
		{
			Other->Cells.Reset(static_cast<int32>(Other->Index.size()));
			for (const MBPaint::FCell& C : Other->Index) Other->Cells.Add(FIntVector(C.X, C.Y, C.Z));
		}
	}
	if (N == 0) return 0;
	// Rewritten in ONE pass from the index: removing cell by cell from a TArray is quadratic.
	Cells.Reset(static_cast<int32>(Index.size()));
	for (const MBPaint::FCell& C : Index) Cells.Add(FIntVector(C.X, C.Y, C.Z));
	RebuildWorld();
	return N;
}

TArray<AMarchingBlocksWorld*> AMarchingBlocksWorld::GetLayers() const
{
	TArray<AMarchingBlocksWorld*> Out;
	UWorld* W = GetWorld();
	if (WorldName.IsNone() || W == nullptr)
	{
		Out.Add(const_cast<AMarchingBlocksWorld*>(this));
		return Out;
	}
	for (TActorIterator<AMarchingBlocksWorld> It(W); It; ++It)
		if (IsValid(*It) && It->WorldName == WorldName) Out.Add(*It);
	Out.Sort([](const AMarchingBlocksWorld& A, const AMarchingBlocksWorld& B)
	{
		return A.Priority != B.Priority ? A.Priority < B.Priority : A.GetName() < B.GetName();
	});
	return Out;
}

namespace MarchingBlocksWorldDetail
{
	// While the whole world is rebuilt, the layers do not lay the transitions one by one: once, at the end.
	int32 RebuildingWorld = 0;
}

void AMarchingBlocksWorld::RebuildWorld()
{
	++MarchingBlocksWorldDetail::RebuildingWorld;
	for (AMarchingBlocksWorld* L : GetLayers()) L->Rebuild();
	--MarchingBlocksWorldDetail::RebuildingWorld;
	// The transitions read every layer: they are laid again once all of them are rebuilt.
	if (AMarchingBlocksTransitions* T = AMarchingBlocksTransitions::Find(GetWorld(), WorldName)) T->Apply();
	// The water follows the world: stale now, rebuilt about half a second after the last gesture (never during one).
	AMarchingBlocksWater::NoteWorldEdited(GetWorld(), WorldName);
}

FMatrix AMarchingBlocksWorld::FormatToWorld() const
{
	const double S = CellSize / FrameUnit;
	return FMatrix(FrameX * S, FrameY * S, FrameZ * S, FVector::ZeroVector) * GetActorTransform().ToMatrixWithScale();
}

FVector AMarchingBlocksWorld::FormatToWorldPosition(const FVector& FormatPoint) const
{
	return GetActorTransform().TransformPosition(FormatToLocal(FormatPoint));
}

FVector AMarchingBlocksWorld::WorldToFormatPosition(const FVector& WorldPoint) const
{
	return LocalToFormat(GetActorTransform().InverseTransformPosition(WorldPoint));
}

FTransform AMarchingBlocksWorld::PlacedTransform(const FVector& FormatOrigin, double Yaw, double Scale) const
{
	// F · R(yaw) · F⁻¹ (MBFrame::Turn), as the ROWS of an Unreal matrix: a proper rotation even though F mirrors.
	const std::array<MBPaint::FVec3, 3> M = Frame().Turn(Yaw);
	const FQuat Turn(FMatrix(MarchingBlocksWorldDetail::ToFVector(M[0]), MarchingBlocksWorldDetail::ToFVector(M[1]),
		MarchingBlocksWorldDetail::ToFVector(M[2]), FVector::ZeroVector));
	const FTransform Local(Turn, FormatToLocal(FormatOrigin), FVector(Scale * CellSize / FrameUnit));
	return Local * GetActorTransform();
}

bool AMarchingBlocksWorld::IsLayerVisible() const
{
#if WITH_EDITOR
	const UWorld* W = GetWorld();
	if (W != nullptr && !W->IsGameWorld()) return !IsHiddenEd();
#endif
	return !IsHidden();
}

void AMarchingBlocksWorld::RunTransacted(const TCHAR* Name, TFunctionRef<void()> Body)
{
#if WITH_EDITOR
	FScopedTransaction Transaction(FText::FromString(Name));
	Modify();
#endif
	Body();
}

int32 AMarchingBlocksWorld::Operate(MBPaint::ESelectionOp Op, const TCHAR* UndoName)
{
	if (Selection.empty())
	{
		Status = TEXT("Nothing selected. Drag a Rect or a Box, or paint with Select, in the MarchingBlocks mode.");
		return 0;
	}
	int32 N = 0;
	RunTransacted(UndoName, [&]()
	{
		const MBPaint::FChange Change = MBPaint::Tools::Operate(GetCells(), Selection, Op);
		N = Apply(Change);
		Selection = Change.Selection;
		// The floor FOLLOWS the extrusion, so fill, extrude, fill… keeps going without Page Up.
		if (Op == MBPaint::ESelectionOp::ExtrudeUp) ++Floor;
		if (Op == MBPaint::ESelectionOp::ExtrudeDown) --Floor;
	});
	Status = FString::Printf(TEXT("%s — %d cell(s) changed, %d selected."), UndoName, N, static_cast<int32>(Selection.size()));
	return N;
}

MBPaint::FShapeRequest AMarchingBlocksWorld::ShapeSettings() const
{
	MBPaint::FShapeRequest R;
	R.Shape = SpecialShape == EMarchingBlocksSpecialShape::Well ? MBPaint::ESpecialShape::Well
		: SpecialShape == EMarchingBlocksSpecialShape::Bridge ? MBPaint::ESpecialShape::Bridge
		: SpecialShape == EMarchingBlocksSpecialShape::Balcony ? MBPaint::ESpecialShape::Balcony
		: SpecialShape == EMarchingBlocksSpecialShape::Stairs ? MBPaint::ESpecialShape::Stairs
		: SpecialShape == EMarchingBlocksSpecialShape::Room ? MBPaint::ESpecialShape::Room : MBPaint::ESpecialShape::Tunnel;
	R.Profile = ShapeProfile == EMarchingBlocksShapeProfile::Square ? MBPaint::EShapeProfile::Square
		: ShapeProfile == EMarchingBlocksShapeProfile::Arch ? MBPaint::EShapeProfile::Arch : MBPaint::EShapeProfile::Round;
	R.Size = ShapeSize;
	R.Length = ShapeLength;
	R.bRail = bShapeRail;
	R.Step = StairsStep;
	return R;
}

void AMarchingBlocksWorld::MoveSelection(const MBPaint::FCell& Offset)
{
	if (Selection.empty()) return;
	RunTransacted(TEXT("Move"), [&]()
	{
		const MBPaint::FChange Change = MBPaint::Tools::Move(GetCells(), Selection, Offset);
		Apply(Change);
		Selection = Change.Selection;
	});
}

void AMarchingBlocksWorld::SetLayer(const FString& TilesetFile, const FString& InTilesFolder, const std::vector<MBPaint::FCell>& InCells)
{
	Tileset.FilePath = TilesetFile;
	TilesFolder.Path = InTilesFolder;
	// Nothing of a previous source survives: a stale manifest or mesh map would draw another tileset.
	ManifestText.Reset();
	TileMeshes.Reset();
	Rule.Reset();
	Status.Reset();
	Cells.Reset(static_cast<int32>(InCells.size()));
	for (const MBPaint::FCell& C : InCells) Cells.Add(FIntVector(C.X, C.Y, C.Z));
	bIndexValid = false;
	Selection.clear();
	Rebuild();
	AMarchingBlocksWater::NoteWorldEdited(GetWorld(), WorldName);
	if (TilesetFile.IsEmpty())
		Status = FString::Printf(TEXT("This layer has no tiles (it was exported without a tileset): its %d cell(s) are kept, nothing is drawn."),
			Cells.Num());
}

bool AMarchingBlocksWorld::HasTileMeshes() const
{
	return TileMeshes.Contains(TEXT("mb_frame"));
}

MBPaint::FVariantSettings AMarchingBlocksWorld::GetVariantSettings() const
{
	MBPaint::FVariantSettings S;
	for (const TPair<FString, FMarchingBlocksVariantWeights>& Entry : VariantWeights)
	{
		std::vector<int64_t> W;
		for (const int32 X : Entry.Value.Weights) W.push_back(X);
		S.Weights[std::string(TCHAR_TO_UTF8(*Entry.Key))] = W;
	}
	for (const TPair<FIntVector, int32>& Entry : VariantChoices)
		S.Choices[MBPaint::FCell(Entry.Key.X, Entry.Key.Y, Entry.Key.Z)] = Entry.Value;
	return S;
}

void AMarchingBlocksWorld::SetVariants(const MBPaint::FVariantSettings& Settings)
{
	VariantWeights.Reset();
	for (const auto& Entry : Settings.Weights)
	{
		FMarchingBlocksVariantWeights W;
		for (const int64_t X : Entry.second) W.Weights.Add(static_cast<int32>(X));
		VariantWeights.Add(FString(UTF8_TO_TCHAR(Entry.first.c_str())), W);
	}
	VariantChoices.Reset();
	for (const auto& Entry : Settings.Choices)
		VariantChoices.Add(FIntVector(Entry.first.X, Entry.first.Y, Entry.first.Z), static_cast<int32>(Entry.second));
}

bool AMarchingBlocksWorld::VariantAt(const MBPaint::FCell& Vertex, FString& OutKey, int32& OutCount, int32& OutCurrent) const
{
	OutCount = 0;
	OutCurrent = 0;
	const auto Placed = PlacedTiles.find(Vertex);
	if (!Rule || Placed == PlacedTiles.end() || Placed->second.empty()) return false;
	for (const auto& Entry : Rule->Tiles)
	{
		const auto List = Rule->Variants.find(Entry.first);
		int32 Rank = Entry.second == Placed->second ? 0 : -1;
		if (Rank < 0 && List != Rule->Variants.end())
			for (size_t K = 0; K < List->second.size(); ++K)
				if (List->second[K] == Placed->second) Rank = static_cast<int32>(K) + 1;
		if (Rank < 0) continue;
		OutKey = FString(UTF8_TO_TCHAR(Entry.first.c_str()));
		OutCount = List != Rule->Variants.end() ? static_cast<int32>(List->second.size()) : 0;
		OutCurrent = Rank;
		return true;
	}
	return false;
}

bool AMarchingBlocksWorld::TileUnderRay(const FVector& WorldOrigin, const FVector& WorldDirection, MBPaint::FCell& OutVertex)
{
	const FVector O = LocalToFormat(GetActorTransform().InverseTransformPosition(WorldOrigin));
	const FVector D = LocalToFormat(GetActorTransform().InverseTransformVector(WorldDirection));
	const MBPaint::FCellSet& Here = GetCells();
	const MBPaint::FHit Hit = MBPaint::Tools::Ray([&Here](const MBPaint::FCell& C) { return Here.count(C) > 0; },
		O.X, O.Y, O.Z, D.X, D.Y, D.Z, 2000.0, nullptr);
	if (!Hit.bTouched) return false;
	OutVertex = MBPaint::Tools::TileVertex(O.X, O.Y, O.Z, D.X, D.Y, D.Z, Hit.Cell, Hit.Normal);
	return true;
}

void AMarchingBlocksWorld::ClickVariant(const MBPaint::FCell& Vertex, bool bBackToDraw)
{
	FString Key;
	int32 Count = 0, Current = 0;
	if (!VariantAt(Vertex, Key, Count, Current)) { Status = TEXT("Variant — no tile of this layer there."); return; }
	if (Count == 0) { Status = FString::Printf(TEXT("Variant — '%s' has no variant."), *Key); return; }
	const FIntVector At(Vertex.X, Vertex.Y, Vertex.Z);
	if (bBackToDraw && !VariantChoices.Contains(At)) { Status = TEXT("Variant — this tile already follows the random draw."); return; }
	const int32 Next = (Current + 1) % (Count + 1);
	RunTransacted(TEXT("Variant"), [&]()
	{
		if (bBackToDraw) VariantChoices.Remove(At);
		else VariantChoices.Add(At, Next);
		Rebuild();
	});
	Status = bBackToDraw ? FString::Printf(TEXT("Variant — '%s' is back to the random draw."), *Key)
		: FString::Printf(TEXT("Variant — '%s': %s. Shift + click gives it back to the draw."), *Key,
			Next == 0 ? TEXT("the base tile") : *FString::Printf(TEXT("variant %d"), Next));
}

void AMarchingBlocksWorld::Fill() { Operate(MBPaint::ESelectionOp::Fill, TEXT("Fill")); }
void AMarchingBlocksWorld::DeleteSelected() { Operate(MBPaint::ESelectionOp::Delete, TEXT("Delete")); }
// ⚠ EXTRUDE IS MBCore's Editing::Extrude (editing_conformance.json), no longer the old ExtrudeUp / ExtrudeDown selection
// operations — those stay in MBTools only for tools_conformance.json, until the three plugins have migrated (PARITE §6).
void AMarchingBlocksWorld::ExtrudeUp() { Extrude(MBPaint::EExtrudeDirection::Up, MBPaint::EExtrudeMode::Place); }
void AMarchingBlocksWorld::ExtrudeDown() { Extrude(MBPaint::EExtrudeDirection::Down, MBPaint::EExtrudeMode::Place); }
void AMarchingBlocksWorld::ExtrudeFacing() { Extrude(MBPaint::EExtrudeDirection::Facing, MBPaint::EExtrudeMode::Place); }
void AMarchingBlocksWorld::ExtendSelectionUp() { Extrude(MBPaint::EExtrudeDirection::Up, MBPaint::EExtrudeMode::Extend); }
void AMarchingBlocksWorld::ExtendSelectionDown() { Extrude(MBPaint::EExtrudeDirection::Down, MBPaint::EExtrudeMode::Extend); }
void AMarchingBlocksWorld::Grow() { Operate(MBPaint::ESelectionOp::Grow, TEXT("Grow")); }

// Shrink is the EDGE rule of MarchingBlocks 0.9 (retrecir_bord), no longer the old "six neighbours selected".
void AMarchingBlocksWorld::Shrink()
{
	if (Selection.empty()) { Status = TEXT("Shrink — nothing selected."); return; }
	SetSelectionSaid(MBPaint::Editing::ShrinkEdge(Selection), TEXT("Shrink"));
}

void AMarchingBlocksWorld::Widen()
{
	if (Selection.empty()) { Status = TEXT("Widen — nothing selected."); return; }
	SetSelectionSaid(MBPaint::Editing::WidenFlat(Selection), TEXT("Widen"));
}

int32 AMarchingBlocksWorld::Extrude(MBPaint::EExtrudeDirection Direction, MBPaint::EExtrudeMode Mode)
{
	const MBPaint::FExtrudeResult R = MBPaint::Editing::Extrude(GetCells(), Floor, Direction, Selection, Mode);
	const TCHAR* Name = Mode == MBPaint::EExtrudeMode::Extend ? TEXT("Extend selection")
		: Mode == MBPaint::EExtrudeMode::Shift ? TEXT("Shift selection") : TEXT("Extrude");
	if (R.Step.IsZero())
	{
		Status = FString::Printf(TEXT("%s — nothing to do: %s"), Name, Selection.empty()
			? TEXT("no matter on this floor, and no selection.") : TEXT("no direction where the selection faces the air."));
		return 0;
	}
	int32 N = 0;
	RunTransacted(Name, [&]()
	{
		MBPaint::FChange Change;
		Change.Set = R.Set;
		Change.Clear = R.Clear;
		N = Change.IsEmpty() ? 0 : Apply(Change);
		Selection = R.Selection;
		// The floor FOLLOWS the step, so fill, extrude, fill… keeps going without Page Up.
		Floor += R.Step.Y;
	});
	Status = FString::Printf(TEXT("%s (%d, %d, %d) — %d cell(s) placed, %d selected."), Name, R.Step.X, R.Step.Y, R.Step.Z, N,
		static_cast<int32>(Selection.size()));
	return N;
}

void AMarchingBlocksWorld::SetSelectionSaid(const MBPaint::FCellSet& NewSelection, const TCHAR* What)
{
	// The selection is not saved with the level (like every selection tool of the mode): no undo record.
	Selection = NewSelection;
	Status = FString::Printf(TEXT("%s — %d selected."), What, static_cast<int32>(Selection.size()));
}

void AMarchingBlocksWorld::RoomFromSelection()
{
	const MBPaint::FShapeResult R = MBPaint::Shapes::RoomFromSelection(GetCells(), Selection, RoomFloors, bRoomUp);
	if (!R.Error.empty())
	{
		Status = R.Error == "empty" ? FString(TEXT("Room from selection — nothing selected."))
			: R.Error == "too_small" ? FString(TEXT("Room from selection — too small: no selected cell has its four neighbours selected. Select at least 3 x 3."))
			: FString::Printf(TEXT("Room from selection — too large: more than %lld cells."), MBPaint::Shapes::VolumeMax);
		return;
	}
	int32 N = 0;
	RunTransacted(TEXT("Room from selection"), [&]()
	{
		MBPaint::FChange Change;
		Change.Set = R.Set;
		Change.Clear = R.Clear;
		N = Apply(Change);
	});
	Status = FString::Printf(TEXT("Room from selection — %d cell(s) changed%s."), N,
		R.Repaired > 0 ? *FString::Printf(TEXT(", %d more so that no two cells touch by an edge only"), R.Repaired) : TEXT(""));
}

bool AMarchingBlocksWorld::VisibleMatterBounds(FBox& OutWorldBox)
{
	OutWorldBox = FBox(ForceInit);
	for (AMarchingBlocksWorld* L : GetLayers())
	{
		if (!L->IsLayerVisible()) continue;
		for (const MBPaint::FCell& C : L->GetCells())
		{
			const FMatrix M = L->CellMatrix(C);
			OutWorldBox += M.TransformPosition(FVector(-0.5));
			OutWorldBox += M.TransformPosition(FVector(0.5));
		}
	}
	return OutWorldBox.IsValid != 0;
}
void AMarchingBlocksWorld::SelectConnected() { Operate(MBPaint::ESelectionOp::Connected, TEXT("Connected")); }
void AMarchingBlocksWorld::ClearSelection() { Selection.clear(); bPasting = false; }

void AMarchingBlocksWorld::CopySelection()
{
	Clipboard = MBPaint::Tools::Copy(GetCells(), Selection);
	Status = Clipboard.empty() ? FString(TEXT("Nothing to copy: the selection holds no matter."))
		: FString::Printf(TEXT("Copied %d cell(s)."), static_cast<int32>(Clipboard.size()));
}

void AMarchingBlocksWorld::CutSelection()
{
	CopySelection();
	if (!Clipboard.empty()) Operate(MBPaint::ESelectionOp::Delete, TEXT("Cut"));
}

void AMarchingBlocksWorld::PasteClipboard()
{
	bPasting = !Clipboard.empty();
	Status = bPasting ? FString(TEXT("Pasting — click in the viewport, in the MarchingBlocks mode (Esc cancels)."))
		: FString(TEXT("The clipboard is empty."));
}

void AMarchingBlocksWorld::ClearCells()
{
	RunTransacted(TEXT("Clear cells"), [&]()
	{
		Cells.Reset();
		bIndexValid = false;
		Selection.clear();
		// The whole world: the other layers' borders, the transitions and the water follow (it rebuilt this layer only
		// until 7 October 2026 — the water never heard of it).
		RebuildWorld();
	});
}

// ── The frame ────────────────────────────────────────────────────────────────────────────────────

FVector AMarchingBlocksWorld::FormatToLocal(const FVector& P) const
{
	return MarchingBlocksWorldDetail::ToFVector(Frame().ToImported(MarchingBlocksWorldDetail::ToVec3(P))) * (CellSize / FrameUnit);
}

FVector AMarchingBlocksWorld::LocalToFormat(const FVector& Q) const
{
	return MarchingBlocksWorldDetail::ToFVector(Frame().ToFormat(MarchingBlocksWorldDetail::ToVec3(Q / (CellSize / FrameUnit))));
}

FVector AMarchingBlocksWorld::WorldDirectionToFormat(const FVector& Direction)
{
	const FVector Local = GetActorTransform().InverseTransformVector(Direction);
	return LocalToFormat(Local).GetSafeNormal();
}

MBPaint::FHit AMarchingBlocksWorld::RayAgainstCells(const FVector& WorldOrigin, const FVector& WorldDirection,
	const MBPaint::FCellSet* Ignore)
{
	const FVector O = LocalToFormat(GetActorTransform().InverseTransformPosition(WorldOrigin));
	const FVector D = LocalToFormat(GetActorTransform().InverseTransformVector(WorldDirection));
	const MBPaint::FCellSet& Here = GetCells();
	return MBPaint::Tools::Ray([&Here](const MBPaint::FCell& C) { return Here.count(C) > 0; },
		O.X, O.Y, O.Z, D.X, D.Y, D.Z, 2000.0, Ignore);
}

bool AMarchingBlocksWorld::CellUnderRay(const FVector& WorldOrigin, const FVector& WorldDirection, MBPaint::FCell& OutCell)
{
	const FVector O = LocalToFormat(GetActorTransform().InverseTransformPosition(WorldOrigin));
	const FVector D = LocalToFormat(GetActorTransform().InverseTransformVector(WorldDirection));
	if (FMath::Abs(D.Y) < 1e-6) return false;
	const double T = (Floor - O.Y) / D.Y;
	if (T <= 0.0) return false;
	const FVector Hit = O + D * T;
	// Cell c covers [c, c+1]: the FLOOR of the hit, never a rounding.
	OutCell = MBPaint::FCell(FMath::FloorToInt32(Hit.X), Floor, FMath::FloorToInt32(Hit.Z));
	return true;
}

FMatrix AMarchingBlocksWorld::CellMatrix(const MBPaint::FCell& Cell)
{
	const double S = CellSize / FrameUnit;
	const FVector Origin = FormatToLocal(FVector(Cell.X + 0.5, Cell.Y + 0.5, Cell.Z + 0.5));
	// Rows are the images of the unit axes (Unreal multiplies row vectors).
	const FMatrix Local(FrameX * S, FrameY * S, FrameZ * S, Origin);
	return Local * GetActorTransform().ToMatrixWithScale();
}

bool AMarchingBlocksWorld::MeasureFrame(UStaticMesh* Marker)
{
	const FStaticMeshRenderData* Data = Marker ? Marker->GetRenderData() : nullptr;
	if (!Data || Data->LODResources.Num() == 0)
	{
		Status = TEXT("The frame marker has no geometry: re-import tiles.glb.");
		return false;
	}
	const FPositionVertexBuffer& Positions = Data->LODResources[0].VertexBuffers.PositionVertexBuffer;
	std::vector<MBPaint::FVec3> Points;
	for (uint32 I = 0; I < Positions.GetNumVertices(); ++I)
		Points.push_back(MarchingBlocksWorldDetail::ToVec3(FVector(Positions.VertexPosition(I))));
	MBPaint::FFrame Measured;
	std::string Error;
	if (!MBPaint::FFrame::Measure(Points, Measured, Error))
	{
		Status = UTF8_TO_TCHAR(Error.c_str());
		return false;
	}
	FrameX = MarchingBlocksWorldDetail::ToFVector(Measured.AxisX);
	FrameY = MarchingBlocksWorldDetail::ToFVector(Measured.AxisY);
	FrameZ = MarchingBlocksWorldDetail::ToFVector(Measured.AxisZ);
	FrameUnit = static_cast<float>(Measured.Unit);
	return true;
}

// ── Loading ──────────────────────────────────────────────────────────────────────────────────────

void AMarchingBlocksWorld::LoadTileset()
{
	Rule.Reset();
#if WITH_EDITOR
	if (!Tileset.FilePath.IsEmpty())
	{
		const FString Path = FPaths::ConvertRelativePathToFull(FPaths::ProjectDir(), Tileset.FilePath);
		FString Text;
		if (FFileHelper::LoadFileToString(Text, *Path))
		{
			ManifestText = Text;
			LoadAnimations(Path);
		}
		else Status = FString::Printf(TEXT("Cannot read %s"), *Path);
	}
	FindTileMeshes();
#endif
	if (ManifestText.IsEmpty()) { Status = TEXT("No tileset.json chosen."); return; }
	MBPaint::FJsonValue Manifest;
	std::string Error;
	if (!MBPaint::ParseJson(TCHAR_TO_UTF8(*ManifestText), Manifest, Error))
	{
		Status = FString::Printf(TEXT("tileset.json is not valid JSON: %s"), UTF8_TO_TCHAR(Error.c_str()));
		return;
	}
	if (Manifest["format"].String != MBPaint::FRule::Format) { Status = TEXT("Not a MarchingBlocks tileset."); return; }
	const std::string Why = MBPaint::FRule::CheckManifest(Manifest);
	if (!Why.empty()) { Status = UTF8_TO_TCHAR(Why.c_str()); return; }
	Rule = MakeUnique<MBPaint::FRule>(Manifest);
}

void AMarchingBlocksWorld::FindTileMeshes()
{
#if WITH_EDITOR
	if (TilesFolder.Path.IsEmpty()) return;
	TileMeshes.Reset();
	FAssetRegistryModule& Registry = FModuleManager::LoadModuleChecked<FAssetRegistryModule>(TEXT("AssetRegistry"));
	TArray<FAssetData> Assets;
	Registry.Get().GetAssetsByPath(FName(*TilesFolder.Path), Assets, true);
	for (const FAssetData& Asset : Assets)
	{
		UStaticMesh* Mesh = Cast<UStaticMesh>(Asset.GetAsset());
		if (!Mesh) continue;
		// Importers name a mesh after the glTF mesh, sometimes with an "SM_" prefix: accept both.
		FString Name = Asset.AssetName.ToString();
		if (Name.StartsWith(TEXT("SM_"), ESearchCase::IgnoreCase)) Name.RightChopInline(3);
		TileMeshes.Add(Name.ToLower(), Mesh);
	}
	TObjectPtr<UStaticMesh>* Marker = TileMeshes.Find(TEXT("mb_frame"));
	if (!Marker) Status = TEXT("No frame marker 'mb_frame' in the tiles folder: import tiles.glb there, Combine Meshes OFF.");
	else MeasureFrame(*Marker);
#endif
}

// ── Building ─────────────────────────────────────────────────────────────────────────────────────

void AMarchingBlocksWorld::Rebuild()
{
	for (UInstancedStaticMeshComponent* C : Generated)
		if (IsValid(C)) C->DestroyComponent();
	Generated.Reset();
	AnimatedLooks.Reset();
	if (!Rule) LoadTileset();
	if (!Rule) return;

	const double S = CellSize / FrameUnit;
	const MBPaint::FFrame F = Frame();
	FQuat Turns[4];
	for (int32 Q = 0; Q < 4; ++Q)
	{
		// F · R · F⁻¹ (MBFrame), as the images of the unit axes: the ROWS of an Unreal matrix, which
		// multiplies row vectors. A proper rotation even though F mirrors.
		const std::array<MBPaint::FVec3, 3> M = F.QuarterTurn(Q);
		Turns[Q] = FQuat(FMatrix(MarchingBlocksWorldDetail::ToFVector(M[0]), MarchingBlocksWorldDetail::ToFVector(M[1]),
			MarchingBlocksWorldDetail::ToFVector(M[2]), FVector::ZeroVector));
	}

	TMap<FString, UInstancedStaticMeshComponent*> ByTile;
	auto ComponentFor = [&](const FString& Key, UStaticMesh* Mesh) -> UInstancedStaticMeshComponent*
	{
		if (UInstancedStaticMeshComponent** Found = ByTile.Find(Key)) return *Found;
		UInstancedStaticMeshComponent* C = NewObject<UInstancedStaticMeshComponent>(this, NAME_None, RF_Transient);
		C->SetStaticMesh(Mesh);
		// PER INSTANCE: the tile's vertex v (format space) and its animation phase — what the transitions and the
		// animated textures read (a material cannot be trusted to find an instance's own position, §9 of PARITE.md).
		C->SetNumCustomDataFloats(4);
		if (Mesh)
			for (int32 Slot = 0; Slot < Mesh->GetStaticMaterials().Num(); ++Slot)
				if (UMaterialInterface* Look = LookOf(Mesh->GetMaterial(Slot))) C->SetMaterial(Slot, Look);
		C->SetupAttachment(GetRootComponent());
		C->RegisterComponent();
		Generated.Add(C);
		ByTile.Add(Key, C);
		return C;
	};

	UStaticMesh* Cube = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cube.Cube"));
	UMaterialInterface* Base = LoadObject<UMaterialInterface>(nullptr, TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"));
	UMaterialInstanceDynamic* Red = nullptr;

	int32 Placed = 0, Missing = 0;
	const MBPaint::FCell Offset = Rule->PieceOffset;
	// Step 7: the rule reads EVERY layer of the world; this layer keeps the vertices it owns.
	const TArray<AMarchingBlocksWorld*> WorldLayers = GetLayers();
	std::vector<MBPaint::FLayerInput> In(static_cast<size_t>(WorldLayers.Num()));
	size_t Mine = 0;
	for (int32 I = 0; I < WorldLayers.Num(); ++I)
	{
		MBPaint::FLayerInput& L = In[static_cast<size_t>(I)];
		L.Cells = &WorldLayers[I]->GetCells();
		L.bVisible = WorldLayers[I]->IsLayerVisible();
		L.Rule = WorldLayers[I] == this ? Rule.Get() : nullptr;
		if (WorldLayers[I] == this) Mine = static_cast<size_t>(I);
	}
	const MBPaint::FVariantSettings Settings = GetVariantSettings();
	In[Mine].Variants = &Settings;
	PlacedTiles.clear();
	// ⚠ KEPT IN A LOCAL: a range-for over PlacementsLayered(In)[Mine] would walk a reference into a temporary destroyed
	// before the loop (C++ extends the life of the range expression only) — measured: a crash in the world import.
	const std::vector<std::vector<MBPaint::FPlacement>> AllPlacements = MBPaint::FRule::PlacementsLayered(In);
	for (const MBPaint::FPlacement& P : AllPlacements[Mine])
	{
		PlacedTiles[P.Vertex] = P.Tile;
		const FVector Centre = FormatToLocal(FVector(P.Vertex.X + Offset.X, P.Vertex.Y + Offset.Y, P.Vertex.Z + Offset.Z));
		const TObjectPtr<UStaticMesh>* Found = P.Tile.empty() ? nullptr
			: TileMeshes.Find(FString(UTF8_TO_TCHAR(P.Tile.c_str())).ToLower());
		UStaticMesh* Mesh = Found ? Found->Get() : nullptr;
		if (!Mesh)
		{
			// A red cube where the tileset lacks the tile. Nothing is ever filled in.
			++Missing;
			if (!Cube) continue;
			UInstancedStaticMeshComponent* C = ComponentFor(TEXT("<missing>"), Cube);
			if (!Red && Base)
			{
				Red = UMaterialInstanceDynamic::Create(Base, this);
				Red->SetVectorParameterValue(TEXT("Color"), FLinearColor(0.9f, 0.2f, 0.15f));
				C->SetMaterial(0, Red);
			}
			C->AddInstance(FTransform(FQuat::Identity, Centre, FVector(CellSize * 0.5 / 100.0)));
			continue;
		}
		UInstancedStaticMeshComponent* C = ComponentFor(FString(UTF8_TO_TCHAR(P.Tile.c_str())), Mesh);
		const int32 Instance = C->AddInstance(FTransform(Turns[((P.QuarterTurns % 4) + 4) % 4], Centre, FVector(S)));
		// The phase of a tile comes from its ORIGIN in format space (v + piece_offset), computed HERE in double: a 32-bit
		// shader would differ up to 0.025 (PARITE §7).
		const float Data[4] = {static_cast<float>(P.Vertex.X), static_cast<float>(P.Vertex.Y), static_cast<float>(P.Vertex.Z),
			static_cast<float>(MBPaint::Animation::PhaseOf(P.Vertex.X + Offset.X, P.Vertex.Y + Offset.Y, P.Vertex.Z + Offset.Z))};
		C->SetCustomData(Instance, MakeArrayView(Data, 4), false);
		++Placed;
	}
	// A layer rebuilt alone (its construction, a property) lays the transitions of its world again: its tiles are new.
	if (MarchingBlocksWorldDetail::RebuildingWorld == 0)
		if (AMarchingBlocksTransitions* T = AMarchingBlocksTransitions::Find(GetWorld(), WorldName)) T->Apply();
	if (Missing > 0) Status = FString::Printf(TEXT("%d tile(s) · %d missing (red)"), Placed, Missing);
	else if (Status.IsEmpty() || Status.Contains(TEXT("tile(s)"))) Status = FString::Printf(TEXT("%d tile(s)"), Placed);
}

// ── Animated textures ────────────────────────────────────────────────────────────────────────────

void AMarchingBlocksWorld::LoadAnimations(const FString& TilesetPath)
{
	AnimationsJson.Reset();
	AnimationImages.Reset();
	const FString Folder = FPaths::GetPath(TilesetPath);
	TArray<uint8> Glb;
	if (!FFileHelper::LoadFileToArray(Glb, *(Folder / TEXT("tiles.glb")))) return;
	MBPaint::FJsonValue Gltf;
	std::string Error;
	if (!MBPaint::Animation::ReadGlbJson(std::vector<uint8_t>(Glb.GetData(), Glb.GetData() + Glb.Num()), Gltf, Error))
	{
		Status = FString::Printf(TEXT("tiles.glb: %s"), UTF8_TO_TCHAR(Error.c_str()));
		return;
	}
	// Kept in the level as the glb's own JSON text (a packaged game has no tiles.glb) — only when an animation is there.
	TSet<FString> Wanted;
	const std::map<std::string, MBPaint::FAnimation> ByName = MBPaint::Animation::ByMaterial(Gltf);
	for (const auto& Entry : ByName)
		for (const MBPaint::FAnimChannelTracks& T : Entry.second.Channels)
			for (const std::string& I : T.Frames.Images) Wanted.Add(UTF8_TO_TCHAR(I.c_str()));
	if (ByName.empty()) return;
	const uint32 Length = Glb.Num() >= 20 ? static_cast<uint32>(Glb[12]) | (static_cast<uint32>(Glb[13]) << 8)
		| (static_cast<uint32>(Glb[14]) << 16) | (static_cast<uint32>(Glb[15]) << 24) : 0;
	AnimationsJson = FString(UTF8_TO_TCHAR(std::string(reinterpret_cast<const char*>(Glb.GetData()) + 20, Length).c_str()));
	for (const FString& Rel : Wanted)
	{
		FMarchingBlocksImage Image;
		if (MarchingBlocksLooks::LoadImageFile(Folder / Rel, Rel, Image)) AnimationImages.Add(MoveTemp(Image));
		else Status = FString::Printf(TEXT("Animation frame missing: %s (the tile shows magenta there)."), *Rel);
	}
}

UMaterialInterface* AMarchingBlocksWorld::LookOf(UMaterialInterface* Imported)
{
	if (!Imported || !bAnimateTextures || AnimationsJson.Len() < 3) return nullptr;
	if (const TObjectPtr<UMaterialInterface>* Done = AnimatedLooks.Find(Imported)) return *Done;
	AnimatedLooks.Add(Imported, nullptr);
	MBPaint::FJsonValue Gltf;
	std::string Error;
	if (!MBPaint::ParseJson(TCHAR_TO_UTF8(*AnimationsJson), Gltf, Error)) return nullptr;
	const std::map<std::string, MBPaint::FAnimation> ByName = MBPaint::Animation::ByMaterial(Gltf);
	const auto Found = ByName.find(std::string(TCHAR_TO_UTF8(*MarchingBlocksLooks::GltfNameOf(Imported))));
	if (Found == ByName.end()) return nullptr;
	const MBPaint::FAnimation& A = Found->second;
	UMaterialInterface* Base = MarchingBlocksLooks::AnimatedMaterial();
	if (A.IsEmpty() || !Base)
	{
		if (!Base) Status = TEXT("The plugin's animated material is missing (Content/Materials/M_MB_Animated): the tiles stay still.");
		return nullptr;
	}
	UMaterialInstanceDynamic* Mid = UMaterialInstanceDynamic::Create(Base, this);
	// What the imported material shows (frame 0, factors): the animated one starts from it.
	MarchingBlocksLooks::CopyImportedLook(Imported, Mid);
	struct FChannel { const TCHAR* Name; bool bSRGB; };
	const FChannel Channels[4] = {{TEXT("BaseColor"), true}, {TEXT("Normal"), false}, {TEXT("ORM"), false}, {TEXT("Emissive"), true}};
	for (int32 Ch = 0; Ch < 4; ++Ch)
	{
		const FString P = FString(TEXT("MB_")) + Channels[Ch].Name;
		const MBPaint::FAnimChannelTracks& T = A.Channels[Ch];
		if (T.Frames.bPresent)
		{
			TArray<const FMarchingBlocksImage*> Frames;
			for (const std::string& I : T.Frames.Images)
				Frames.Add(AnimationImages.FindByPredicate([&I](const FMarchingBlocksImage& Image) { return Image.Path == UTF8_TO_TCHAR(I.c_str()); }));
			if (UTexture2DArray* Array = MarchingBlocksLooks::MakeArray(Frames, Channels[Ch].bSRGB, this))
			{
				Mid->SetTextureParameterValue(*(P + TEXT("_Frames")), Array);
				Mid->SetScalarParameterValue(*(P + TEXT("_Count")), static_cast<float>(T.Frames.Images.size()));
				Mid->SetScalarParameterValue(*(P + TEXT("_Fps")), static_cast<float>(T.Frames.Fps));
				Mid->SetScalarParameterValue(*(P + TEXT("_PingPong")), T.Frames.bPingPong ? 1.f : 0.f);
				Mid->SetScalarParameterValue(*(P + TEXT("_FramesSynced")), T.Frames.bSynced ? 1.f : 0.f);
			}
		}
		if (T.Scroll.bPresent)
		{
			Mid->SetScalarParameterValue(*(P + TEXT("_Scrolling")), 1.f);
			Mid->SetScalarParameterValue(*(P + TEXT("_ScrollU")), static_cast<float>(T.Scroll.U));
			Mid->SetScalarParameterValue(*(P + TEXT("_ScrollV")), static_cast<float>(T.Scroll.V));
			Mid->SetScalarParameterValue(*(P + TEXT("_ScrollSynced")), T.Scroll.bSynced ? 1.f : 0.f);
		}
		if (T.Pulse.bPresent)
		{
			Mid->SetScalarParameterValue(TEXT("MB_PulseOn"), 1.f);
			Mid->SetScalarParameterValue(TEXT("MB_PulseFrequency"), static_cast<float>(T.Pulse.Frequency));
			Mid->SetScalarParameterValue(TEXT("MB_PulseMinimum"), static_cast<float>(T.Pulse.Minimum));
			Mid->SetScalarParameterValue(TEXT("MB_PulseSynced"), T.Pulse.bSynced ? 1.f : 0.f);
		}
	}
	AnimatedLooks.Add(Imported, Mid);
	return Mid;
}

void AMarchingBlocksWorld::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	Rebuild();
}

MBPaint::FAimState AMarchingBlocksWorld::GetAimState() const
{
	MBPaint::FAimState State;
	State.Aim = Aim == EMarchingBlocksAim::Sculpt ? MBPaint::EAim::Sculpt : MBPaint::EAim::Grid;
	State.bNavigating = bNavigate || Aim == EMarchingBlocksAim::Navigate;
	return State;
}

void AMarchingBlocksWorld::SetAimState(const MBPaint::FAimState& State)
{
	Aim = State.Aim == MBPaint::EAim::Sculpt ? EMarchingBlocksAim::Sculpt : EMarchingBlocksAim::Grid;
	bNavigate = State.bNavigating;
}

// ⚠ A LEVEL SAVED WHEN NAVIGATE WAS STILL AN AIM (before 29 September 2026) comes back as it was left: Grid,
// navigating. The enum value stays (hidden) so the saved name still resolves.
void AMarchingBlocksWorld::PostLoad()
{
	Super::PostLoad();
	if (Aim == EMarchingBlocksAim::Navigate) SetAimState(GetAimState());
}

#if WITH_EDITOR
void AMarchingBlocksWorld::PostEditChangeProperty(FPropertyChangedEvent& Event)
{
	Super::PostEditChangeProperty(Event);
	const FName Name = Event.GetMemberPropertyName();
	if (Name == GET_MEMBER_NAME_CHECKED(AMarchingBlocksWorld, Tileset) || Name == GET_MEMBER_NAME_CHECKED(AMarchingBlocksWorld, TilesFolder))
	{
		Rule.Reset();
		Status.Reset();
		Rebuild();
	}
	// Joining, leaving or reordering a world moves the borders of every layer involved.
	if (Name == GET_MEMBER_NAME_CHECKED(AMarchingBlocksWorld, WorldName) || Name == GET_MEMBER_NAME_CHECKED(AMarchingBlocksWorld, Priority))
	{
		for (TActorIterator<AMarchingBlocksWorld> It(GetWorld()); It; ++It)
			if (IsValid(*It)) It->Rebuild();
	}
	// Choosing an aim in the Details panel leaves navigation, as Tab does. (The hidden legacy value, if code
	// sets it, still means "navigating".)
	if (Name == GET_MEMBER_NAME_CHECKED(AMarchingBlocksWorld, Aim))
	{
		const MBPaint::FAimState State = GetAimState();
		SetAimState(Aim == EMarchingBlocksAim::Navigate ? State : MBPaint::Tools::ChooseAim(State, State.Aim));
	}
}

void AMarchingBlocksWorld::PostEditUndo()
{
	Super::PostEditUndo();
	bIndexValid = false;
	// The undone change may have given cells back to another layer: the whole world is rebuilt.
	for (AMarchingBlocksWorld* L : GetLayers()) L->bIndexValid = false;
	RebuildWorld();
}
#endif
