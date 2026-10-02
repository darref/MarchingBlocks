// MarchingBlocks Paint for Unreal — the world layer actor (see MarchingBlocksWorld.h).

#include "MarchingBlocksWorld.h"

#include "Components/InstancedStaticMeshComponent.h"
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
	if (N == 0) return 0;
	// Rewritten in ONE pass from the index: removing cell by cell from a TArray is quadratic.
	Cells.Reset(static_cast<int32>(Index.size()));
	for (const MBPaint::FCell& C : Index) Cells.Add(FIntVector(C.X, C.Y, C.Z));
	Rebuild();
	return N;
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
		: SpecialShape == EMarchingBlocksSpecialShape::Stairs ? MBPaint::ESpecialShape::Stairs : MBPaint::ESpecialShape::Tunnel;
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
	if (TilesetFile.IsEmpty())
		Status = FString::Printf(TEXT("This layer has no tiles (it was exported without a tileset): its %d cell(s) are kept, nothing is drawn."),
			Cells.Num());
}

bool AMarchingBlocksWorld::HasTileMeshes() const
{
	return TileMeshes.Contains(TEXT("mb_frame"));
}

void AMarchingBlocksWorld::Fill() { Operate(MBPaint::ESelectionOp::Fill, TEXT("Fill")); }
void AMarchingBlocksWorld::DeleteSelected() { Operate(MBPaint::ESelectionOp::Delete, TEXT("Delete")); }
void AMarchingBlocksWorld::ExtrudeUp() { Operate(MBPaint::ESelectionOp::ExtrudeUp, TEXT("Extrude up")); }
void AMarchingBlocksWorld::ExtrudeDown() { Operate(MBPaint::ESelectionOp::ExtrudeDown, TEXT("Extrude down")); }
void AMarchingBlocksWorld::Grow() { Operate(MBPaint::ESelectionOp::Grow, TEXT("Grow")); }
void AMarchingBlocksWorld::Shrink() { Operate(MBPaint::ESelectionOp::Shrink, TEXT("Shrink")); }
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
		Rebuild();
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
		if (FFileHelper::LoadFileToString(Text, *Path)) ManifestText = Text;
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
	for (const MBPaint::FPlacement& P : Rule->Placements(GetCells()))
	{
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
		C->AddInstance(FTransform(Turns[((P.QuarterTurns % 4) + 4) % 4], Centre, FVector(S)));
		++Placed;
	}
	if (Missing > 0) Status = FString::Printf(TEXT("%d tile(s) · %d missing (red)"), Placed, Missing);
	else if (Status.IsEmpty() || Status.Contains(TEXT("tile(s)"))) Status = FString::Printf(TEXT("%d tile(s)"), Placed);
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
	Rebuild();
}
#endif
