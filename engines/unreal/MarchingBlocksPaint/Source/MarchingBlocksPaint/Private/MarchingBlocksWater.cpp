// MarchingBlocks Paint for Unreal — une couche d'eau (voir MarchingBlocksWater.h).
//
// ⚠ LA NAPPE CUITE EST EN ESPACE DU FORMAT, comme les cases : importée par le même importeur glTF que tiles.glb, elle porte
// le même repère F — on la pose donc à l'échelle des couches (taille de case / unité du repère), sans autre rotation.
// ⚠ LES CASES D'EAU se déduisent des cases de TOUTES les couches (cachées comprises : la règle le dit) et des sources de
// toutes les couches d'eau dans leur ordre (la première source dans le vide est LA mer).
//
// L'EAU RECALCULÉE (7 octobre 2026, PARITE.md §12 ; le branchement DÉCIDÉ par la coordination, sur délégation de Jordan) :
//   - JAMAIS PENDANT UN GESTE : la couche de cases appelle NoteWorldEdited à chaque changement (RebuildWorld) ; le mode dit
//     quand un geste est ouvert (SetGestureOpen) ; la nappe affichée reste l'ancienne, dite périmée ;
//   - À LA FIN DU GESTE, après ~0,5 s sans nouveau geste (un ticker du cœur, qui tourne aussi dans l'éditeur), HORS DU FIL
//     DU JEU (une tâche d'Unreal, UE::Tasks) : les cases COPIÉES (les TArray des couches), la reprise de l'appli
//     (Water::WorldResumed contre l'état d'avant, les cases changées relues par différence), la mémoire des nappes ; le
//     résultat est posé sur le fil principal (AsyncTask GameThread) ;
//   - une couche d'eau dont aucun corps n'a changé garde sa nappe (comme l'appli) ;
//   - LE SUIVI AUTOMATIQUE SE COUPE quand un recalcul automatique a duré plus de ~1 s (la nappe reste dite périmée) ; le
//     bouton Rebuild Water est toujours là, et remet le suivi si son recalcul tient sous la seconde.
// ⚠ LA NAPPE RECALCULÉE est posée en ESPACE DU MONDE (FormatToWorld de la couche), composant à l'identité : la même place
// que la nappe cuite, sans dépendre de ce que l'importeur glTF a fait du repère. Le sens des triangles suit le signe de
// cette matrice — vérifié contre la nappe cuite par CompareWithBakedSheet.
// ⚠ Le maillage passe par une UStaticMesh construite à la volée (BuildFromMeshDescriptions, « fast build ») : la même
// conversion des couleurs de sommet (ToFColor sRGB) que la nappe cuite importée — les six presets les lisent pareil.

#include "MarchingBlocksWater.h"

#include "Async/Async.h"
#include "Components/StaticMeshComponent.h"
#include "Containers/Ticker.h"
#include "Engine/StaticMesh.h"
#include "EngineUtils.h"
#include "HAL/IConsoleManager.h"
#include "HAL/PlatformTime.h"
#include "MarchingBlocksLooks.h"
#include "MarchingBlocksWorld.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "MBCore/MBWater.h"
#include "MeshDescription.h"
#include "StaticMeshAttributes.h"
#include "Tasks/Task.h"

#include <array>
#include <chrono>
#include <map>
#include <memory>
#include <vector>

DEFINE_LOG_CATEGORY_STATIC(LogMarchingBlocksWater, Log, All);

namespace MarchingBlocksWaterDetail
{
	TArray<AMarchingBlocksWater*> WaterLayers(UWorld* World, FName WorldName)
	{
		TArray<AMarchingBlocksWater*> Out;
		if (!World) return Out;
		for (TActorIterator<AMarchingBlocksWater> It(World); It; ++It)
			if (IsValid(*It) && It->WorldName == WorldName) Out.Add(*It);
		Out.Sort([](const AMarchingBlocksWater& A, const AMarchingBlocksWater& B) { return A.Order != B.Order ? A.Order < B.Order : A.GetName() < B.GetName(); });
		return Out;
	}

	AMarchingBlocksWorld* FirstLayer(UWorld* World, FName WorldName, bool bWithTiles)
	{
		if (!World) return nullptr;
		for (TActorIterator<AMarchingBlocksWorld> It(World); It; ++It)
			if (IsValid(*It) && It->WorldName == WorldName)
			{
				for (AMarchingBlocksWorld* L : It->GetLayers())
					if (!bWithTiles || L->HasTileMeshes()) return L;
				return It->GetLayers()[0];
			}
		return nullptr;
	}

	/** The cells of every layer of the world, hidden ones too. */
	MBPaint::FCellSet AllCells(UWorld* World, FName WorldName)
	{
		MBPaint::FCellSet Out;
		if (AMarchingBlocksWorld* Any = FirstLayer(World, WorldName, false))
			for (AMarchingBlocksWorld* L : Any->GetLayers())
				for (const MBPaint::FCell& C : L->GetCells()) Out.insert(C);
		return Out;
	}

	double Ms(std::chrono::steady_clock::time_point T0)
	{
		return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - T0).count();
	}

	/** What a rebuild computes OFF the game thread: its inputs are copies, its outputs are moved back. */
	struct FJob
	{
		// In.
		std::vector<TArray<FIntVector>> LayerCells;
		std::vector<MBPaint::FCell> Sources;
		std::vector<size_t> Split;
		MBPaint::FWaterState Before;
		std::shared_ptr<const MBPaint::FCellSet> CellsBefore;
		std::vector<MBPaint::FWaterMeshMemory> Memories;
		std::vector<std::vector<uint64_t>> ShownIds;
		bool bManual = false;
		double Started = 0.0;
		/** When the worker finished (FPlatformTime): the rebuild's own time is Computed - Started (gathering the cells on the
		 *  game thread included); what follows is only the wait for the game thread to tick (slow in an unfocused editor). */
		double Computed = 0.0;
		// Out.
		MBPaint::FWaterState After;
		std::shared_ptr<const MBPaint::FCellSet> Cells;
		std::vector<bool> LayerChanged;
		std::vector<MBPaint::FWaterMesh> Meshes;
		std::vector<MBPaint::FCellSet> LayerWater;
		std::vector<std::vector<uint64_t>> Ids;
		double CellsMs = 0.0, RuleMs = 0.0, SheetMs = 0.0;
		size_t Changed = 0;
		bool bWhole = true;
	};

	/** The follow of ONE world (UWorld + World Name): the last result, kept for the next rebuild. Game thread only. */
	struct FFollow
	{
		TWeakObjectPtr<UWorld> World;
		FName WorldName;
		MBPaint::FWaterState State;
		std::shared_ptr<const MBPaint::FCellSet> Cells;
		std::vector<MBPaint::FWaterMeshMemory> Memories;
		std::vector<std::vector<uint64_t>> ShownIds;
		TArray<TWeakObjectPtr<AMarchingBlocksWater>> ShownLayers;
		bool bStale = false;
		bool bBusy = false;
		bool bAgain = false;
		bool bAuto = true;
		bool bManualWanted = false;
		double Due = 0.0;
		double LastSeconds = -1.0;
		int32 Rebuilds = 0;
		FString LastSaid;
	};

	TArray<TSharedPtr<FFollow>> Follows;
	bool bGestureOpen = false;
	FTSTicker::FDelegateHandle Ticker;
	TAutoConsoleVariable<float> CVarCalm(TEXT("mb.Water.Calm"), 0.5f,
		TEXT("MarchingBlocks: seconds without a gesture before the water is rebuilt (0.5)."));
	TAutoConsoleVariable<float> CVarTooLong(TEXT("mb.Water.AutoRebuildLimit"), 1.0f,
		TEXT("MarchingBlocks: an automatic water rebuild longer than this many seconds switches the automatic follow off (1)."));
	double Calm() { return static_cast<double>(CVarCalm.GetValueOnGameThread()); }
	double TooLong() { return static_cast<double>(CVarTooLong.GetValueOnGameThread()); }

	TSharedPtr<FFollow> FollowOf(UWorld* World, FName WorldName, bool bCreate)
	{
		for (const TSharedPtr<FFollow>& F : Follows)
			if (F->World.Get() == World && F->WorldName == WorldName) return F;
		if (!bCreate) return nullptr;
		TSharedPtr<FFollow> F = MakeShared<FFollow>();
		F->World = World;
		F->WorldName = WorldName;
		Follows.Add(F);
		return F;
	}

	void Launch(const TSharedPtr<FFollow>& F, bool bManual);

	bool Tick(float)
	{
		const double Now = FPlatformTime::Seconds();
		for (int32 I = Follows.Num() - 1; I >= 0; --I)
		{
			const TSharedPtr<FFollow> F = Follows[I];
			if (!F->World.IsValid()) { if (!F->bBusy) Follows.RemoveAt(I); continue; }
			if (!F->bStale || F->bBusy || bGestureOpen || Now < F->Due) continue;
			if (F->bAuto || F->bManualWanted) Launch(F, F->bManualWanted);
		}
		return true;
	}

	void EnsureTicker()
	{
		if (!Ticker.IsValid()) Ticker = FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateStatic(&Tick), 0.05f);
	}

	// THE WORK, on a worker thread: pure functions on copies.
	void Compute(FJob& J)
	{
		auto T0 = std::chrono::steady_clock::now();
		std::shared_ptr<MBPaint::FCellSet> Cells = std::make_shared<MBPaint::FCellSet>();
		size_t Total = 0;
		for (const TArray<FIntVector>& L : J.LayerCells) Total += static_cast<size_t>(L.Num());
		Cells->reserve(Total);
		for (const TArray<FIntVector>& L : J.LayerCells)
			for (const FIntVector& C : L) Cells->insert(MBPaint::FCell(C.X, C.Y, C.Z));
		J.LayerCells.clear();
		// The cells that changed since the last rebuild (none known: everything is computed).
		MBPaint::FCellSet Changed;
		J.bWhole = !J.CellsBefore || !J.Before.bValid;
		if (!J.bWhole) Changed = MBPaint::Water::ChangedBetween(*J.CellsBefore, *Cells);
		J.Changed = Changed.size();
		const MBPaint::FWaterBox Box = MBPaint::Water::BoxOf(*Cells);
		J.CellsMs = Ms(T0);
		T0 = std::chrono::steady_clock::now();
		J.After = MBPaint::Water::WorldResumed(*Cells, J.Sources, J.bWhole ? nullptr : &J.Before, J.bWhole ? nullptr : &Changed, &Box);
		J.RuleMs = Ms(T0);
		T0 = std::chrono::steady_clock::now();
		J.Memories.resize(J.Split.size());
		J.ShownIds.resize(J.Split.size());
		size_t K = 0;
		for (size_t L = 0; L < J.Split.size(); ++L)
		{
			std::vector<const MBPaint::FWaterBody*> Bodies;
			std::vector<uint64_t> Ids;
			for (size_t I = 0; I < J.Split[L]; ++I)
			{
				const MBPaint::FWaterBody* B = J.After.Bodies[K + I].get();
				Bodies.push_back(B);
				// A refused body draws nothing: two refusals are the same (Id 0), as in MarchingBlocks.
				Ids.push_back(B->Error.empty() ? B->Id : 0);
			}
			K += J.Split[L];
			// A layer whose bodies were all taken back keeps its sheet.
			const bool bChanged = Ids != J.ShownIds[L];
			J.LayerChanged.push_back(bChanged);
			J.Ids.push_back(Ids);
			MBPaint::FCellSet LayerCellsOfWater;
			if (bChanged)
			{
				for (const MBPaint::FWaterBody* B : Bodies)
					if (B->Error.empty()) LayerCellsOfWater.insert(B->Water.begin(), B->Water.end());
				J.Meshes.push_back(MBPaint::WaterMesh::Build(Bodies, *Cells, Box, &J.Memories[L]));
			}
			else J.Meshes.emplace_back();
			J.LayerWater.push_back(std::move(LayerCellsOfWater));
		}
		J.SheetMs = Ms(T0);
		J.Cells = Cells;
		J.Computed = FPlatformTime::Seconds();
	}

	void Finish(const TSharedPtr<FFollow>& F, const TSharedPtr<FJob>& J, const TArray<TWeakObjectPtr<AMarchingBlocksWater>>& Layers)
	{
		F->bBusy = false;
		// The rebuild's own time (what the cut-off judges): the cells gathered, the worker's work — not the wait for this tick.
		const double Seconds = J->Computed - J->Started;
		const double Posted = FPlatformTime::Seconds() - J->Computed;
		F->LastSeconds = Seconds;
		F->State = J->After;
		F->Cells = J->Cells;
		F->Memories = std::move(J->Memories);
		F->ShownIds = J->Ids;
		F->ShownLayers = Layers;
		if (J->bManual) F->bAuto = Seconds <= TooLong();
		else if (Seconds > TooLong()) F->bAuto = false;
		F->bManualWanted = false;
		++F->Rebuilds;
		F->LastSaid = FString::Printf(TEXT("Water rebuilt (#%d) in %.2f s, shown %.2f s later (cells %.0f ms, %s; rule %.0f ms, %d of %d sources taken back; sheets %.0f ms)."),
			F->Rebuilds, Seconds, Posted, J->CellsMs, J->bWhole ? TEXT("everything") : *FString::Printf(TEXT("%d changed"), static_cast<int32>(J->Changed)), J->RuleMs,
			J->After.Reused, static_cast<int32>(J->Sources.size()), J->SheetMs);
		if (!F->bAuto)
			F->LastSaid += FString::Printf(TEXT(" More than %.1f s: the water no longer follows by itself — press Rebuild Water."), TooLong());
		UE_LOG(LogMarchingBlocksWater, Log, TEXT("%s"), *F->LastSaid);
		for (int32 L = 0; L < Layers.Num(); ++L)
		{
			AMarchingBlocksWater* W = Layers[L].Get();
			const size_t Li = static_cast<size_t>(L);
			if (!W || Li >= J->Meshes.size()) continue;
			if (J->LayerChanged[Li]) W->ShowRebuiltSheet(std::move(J->Meshes[Li]), std::move(J->LayerWater[Li]), F->LastSaid);
			else W->Status = F->LastSaid + TEXT(" This layer did not change.");
		}
		if (F->bAgain)
		{
			F->bAgain = false;
			F->bStale = true;
			F->Due = FPlatformTime::Seconds() + Calm();
		}
	}

	void Launch(const TSharedPtr<FFollow>& F, bool bManual)
	{
		UWorld* World = F->World.Get();
		const TArray<AMarchingBlocksWater*> Waters = WaterLayers(World, F->WorldName);
		F->bStale = false;
		if (Waters.Num() == 0) return;
		TSharedPtr<FJob> J = MakeShared<FJob>();
		J->Started = FPlatformTime::Seconds();
		J->bManual = bManual;
		TArray<TWeakObjectPtr<AMarchingBlocksWater>> Layers;
		for (AMarchingBlocksWater* W : Waters)
		{
			Layers.Add(W);
			J->Split.push_back(static_cast<size_t>(W->Sources.Num()));
			for (const FIntVector& S : W->Sources) J->Sources.push_back(MBPaint::FCell(S.X, S.Y, S.Z));
		}
		if (AMarchingBlocksWorld* Any = FirstLayer(World, F->WorldName, false))
			for (AMarchingBlocksWorld* L : Any->GetLayers()) J->LayerCells.push_back(L->GetCellArray());
		J->Before = F->State;
		J->CellsBefore = F->Cells;
		// The water layers changed (added, removed, reordered): the sheets start over (the rule still resumes by source).
		if (Layers == F->ShownLayers)
		{
			J->Memories = F->Memories;
			J->ShownIds = F->ShownIds;
		}
		F->bBusy = true;
		for (AMarchingBlocksWater* W : Waters) W->Status = TEXT("Rebuilding the water…");
		UE::Tasks::Launch(UE_SOURCE_LOCATION, [F, J, Layers]()
		{
			Compute(*J);
			AsyncTask(ENamedThreads::GameThread, [F, J, Layers]() { Finish(F, J, Layers); });
		});
	}

	// ── The sheet, in Unreal ─────────────────────────────────────────────────────────────────────────────

	/** Format → the world, for positions and for normals (the inverse transpose), and whether the triangles are listed the
	 *  other way round (decided by the sign of the matrix: checked against the baked sheet, CompareWithBakedSheet). */
	struct FPlacing
	{
		FMatrix ToWorld = FMatrix::Identity;
		FMatrix NormalToWorld = FMatrix::Identity;
		bool bTurn = false;
		double CellSize = 1.0;
	};

	FPlacing PlacingOf(const AMarchingBlocksWorld* Frame)
	{
		FPlacing P;
		if (!Frame) return P;
		P.ToWorld = Frame->FormatToWorld();
		P.NormalToWorld = P.ToWorld.Inverse().GetTransposed();
		P.bTurn = P.ToWorld.Determinant() > 0.0;
		P.CellSize = FVector(P.ToWorld.TransformVector(FVector(1.0, 0.0, 0.0))).Size();
		return P;
	}

	FVector3f PosOf(const FPlacing& P, const MBPaint::FWaterVertex& V)
	{
		return FVector3f(FVector(P.ToWorld.TransformPosition(FVector(V.Position[0], V.Position[1], V.Position[2]))));
	}

	FVector3f NormalOf(const FPlacing& P, const MBPaint::FWaterVertex& V)
	{
		return FVector3f(FVector(P.NormalToWorld.TransformVector(FVector(V.Normal[0], V.Normal[1], V.Normal[2]))).GetSafeNormal());
	}

	/** ⚠ THE COLOURS AS THE IMPORTER KEEPS THEM — MEASURED (7 October 2026, CompareWithBakedSheet): Interchange reads glTF
	 *  COLOR_0 as sRGB and stores it LINEARISED in the mesh description (0.498 → 0.212); the build encodes it back to sRGB
	 *  bytes, which is what the presets read (≈ 0.498). Stored raw, 0.5 came out as ≈ 0.735: another water. The rebuilt
	 *  sheet goes through the same door: its contract values are linearised here, and come out as the baked ones. */
	float SrgbToLinear(float C)
	{
		return C <= 0.04045f ? C / 12.92f : FMath::Pow((C + 0.055f) / 1.055f, 2.4f);
	}

	float LinearToSrgb(float C)
	{
		return C <= 0.0031308f ? C * 12.92f : 1.055f * FMath::Pow(C, 1.f / 2.4f) - 0.055f;
	}

	UStaticMesh* MakeSheet(UObject* Outer, const MBPaint::FWaterMesh& M, const FPlacing& P)
	{
		FMeshDescription Desc;
		FStaticMeshAttributes Attributes(Desc);
		Attributes.Register();
		TVertexAttributesRef<FVector3f> Positions = Attributes.GetVertexPositions();
		TVertexInstanceAttributesRef<FVector3f> Normals = Attributes.GetVertexInstanceNormals();
		TVertexInstanceAttributesRef<FVector3f> Tangents = Attributes.GetVertexInstanceTangents();
		TVertexInstanceAttributesRef<float> Signs = Attributes.GetVertexInstanceBinormalSigns();
		TVertexInstanceAttributesRef<FVector4f> Colors = Attributes.GetVertexInstanceColors();
		TVertexInstanceAttributesRef<FVector2f> UVs = Attributes.GetVertexInstanceUVs();
		UVs.SetNumChannels(1);
		const int32 N = static_cast<int32>(M.Vertices.size());
		Desc.ReserveNewVertices(N);
		Desc.ReserveNewVertexInstances(N);
		Desc.ReserveNewTriangles(static_cast<int32>(M.Indices.size() / 3));
		const FPolygonGroupID Group = Desc.CreatePolygonGroup();
		Attributes.GetPolygonGroupMaterialSlotNames()[Group] = FName(TEXT("Water"));
		TArray<FVertexInstanceID> Instances;
		Instances.Reserve(N);
		for (const MBPaint::FWaterVertex& V : M.Vertices)
		{
			const FVertexID Vertex = Desc.CreateVertex();
			Positions[Vertex] = PosOf(P, V);
			const FVertexInstanceID I = Desc.CreateVertexInstance(Vertex);
			const FVector3f Normal = NormalOf(P, V);
			Normals[I] = Normal;
			// Any tangent across the normal (the presets read world normals; nothing reads a tangent frame).
			const FVector3f Across = FMath::Abs(Normal.Z) < 0.9f ? FVector3f(0.f, 0.f, 1.f) : FVector3f(1.f, 0.f, 0.f);
			Tangents[I] = FVector3f::CrossProduct(Across, Normal).GetSafeNormal();
			Signs[I] = 1.f;
			Colors[I] = FVector4f(SrgbToLinear(V.Color[0]), SrgbToLinear(V.Color[1]), SrgbToLinear(V.Color[2]), V.Color[3]);
			UVs.Set(I, 0, FVector2f(V.UV[0], V.UV[1]));
			Instances.Add(I);
		}
		for (size_t K = 0; K + 2 < M.Indices.size(); K += 3)
		{
			const FVertexInstanceID A = Instances[static_cast<int32>(M.Indices[K])];
			const FVertexInstanceID B = Instances[static_cast<int32>(M.Indices[K + 1])];
			const FVertexInstanceID C = Instances[static_cast<int32>(M.Indices[K + 2])];
			if (P.bTurn) Desc.CreateTriangle(Group, {A, C, B});
			else Desc.CreateTriangle(Group, {A, B, C});
		}
		UStaticMesh* Mesh = NewObject<UStaticMesh>(Outer, NAME_None, RF_Transient);
		// (The imported slot name exists in the editor only: the game target has no such argument.)
		Mesh->GetStaticMaterials().Add(FStaticMaterial(nullptr, FName(TEXT("Water"))));
		UStaticMesh::FBuildMeshDescriptionsParams Params;
		Params.bMarkPackageDirty = false;
		Params.bBuildSimpleCollision = false;
		Params.bCommitMeshDescription = false;
		Params.bFastBuild = true;
		Mesh->BuildFromMeshDescriptions({&Desc}, Params);
		return Mesh;
	}
}

AMarchingBlocksWater::AMarchingBlocksWater()
{
	PrimaryActorTick.bCanEverTick = false;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

MBPaint::FCellSet AMarchingBlocksWater::WaterCellsOf(UWorld* World, FName InWorldName)
{
	using namespace MarchingBlocksWaterDetail;
	MBPaint::FCellSet Out;
	std::vector<MBPaint::FCell> AllSources;
	for (AMarchingBlocksWater* W : WaterLayers(World, InWorldName))
		for (const FIntVector& S : W->Sources) AllSources.push_back(MBPaint::FCell(S.X, S.Y, S.Z));
	if (AllSources.empty()) return Out;
	const MBPaint::FWaterWorld Result = MBPaint::Water::World(AllCells(World, InWorldName), AllSources);
	Out = Result.Sea;
	for (const MBPaint::FWaterBody& B : Result.Bodies) Out.insert(B.Water.begin(), B.Water.end());
	return Out;
}

void AMarchingBlocksWater::RecomputeWater()
{
	using namespace MarchingBlocksWaterDetail;
	WaterCells.clear();
	const TArray<AMarchingBlocksWater*> WaterWorldLayers = WaterLayers(GetWorld(), WorldName);
	std::vector<MBPaint::FCell> AllSources;
	int32 First = 0;
	for (AMarchingBlocksWater* W : WaterWorldLayers)
	{
		if (W == this) First = static_cast<int32>(AllSources.size());
		for (const FIntVector& S : W->Sources) AllSources.push_back(MBPaint::FCell(S.X, S.Y, S.Z));
	}
	const MBPaint::FWaterWorld Result = MBPaint::Water::World(AllCells(GetWorld(), WorldName), AllSources);
	TArray<FString> Said;
	for (int32 K = 0; K < this->Sources.Num(); ++K)
	{
		const MBPaint::FWaterBody& B = Result.Bodies[static_cast<size_t>(First + K)];
		if (!B.Error.empty()) { Said.Add(FString::Printf(TEXT("refused (%s)"), UTF8_TO_TCHAR(B.Error.c_str()))); continue; }
		WaterCells.insert(B.Water.begin(), B.Water.end());
		Said.Add(FString::Printf(TEXT("%s%s %d cell(s)"), UTF8_TO_TCHAR(MBPaint::Water::KindName(B.Kind)),
			B.End != MBPaint::EWaterEnd::None ? *FString::Printf(TEXT(" (%s)"), UTF8_TO_TCHAR(MBPaint::Water::EndName(B.End))) : TEXT(""),
			static_cast<int32>(B.Kind == MBPaint::EWaterKind::River ? B.Course.size() + B.Water.size() : B.Water.size())));
	}
	Status = Said.Num() ? FString::Join(Said, TEXT(" · ")) : FString(TEXT("No source."));
}

void AMarchingBlocksWater::RebuildWater()
{
	if (!RebuildWorldWater(GetWorld(), WorldName)) Status = TEXT("No water layer in this world.");
}

UMaterialInterface* AMarchingBlocksWater::ChosenMaterial(UMaterialInstanceDynamic*& OutMid)
{
	using namespace MarchingBlocksWaterDetail;
	OutMid = nullptr;
	UMaterialInterface* Chosen = Material ? Material.Get() : MarchingBlocksLooks::WaterMaterial(Look);
	if (!Chosen) return nullptr;
	OutMid = UMaterialInstanceDynamic::Create(Chosen, this);
	if (AMarchingBlocksWorld* Frame = FirstLayer(GetWorld(), WorldName, true)) MarchingBlocksLooks::SetFormatRows(OutMid, Frame->FormatToWorld());
	return Chosen;
}

void AMarchingBlocksWater::DrawSheet()
{
	using namespace MarchingBlocksWaterDetail;
	if (SheetComponent) { SheetComponent->DestroyComponent(); SheetComponent = nullptr; }
	if (bRebuilt) { DrawRebuilt(); return; }
	if (!Sheet) { Status = TEXT("No sheet: import water/<name>.glb from the .mbworld folder and set Sheet — or paint: the water is rebuilt here."); return; }
	AMarchingBlocksWorld* Frame = FirstLayer(GetWorld(), WorldName, true);
	SheetComponent = NewObject<UStaticMeshComponent>(this, NAME_None, RF_Transient);
	SheetComponent->SetStaticMesh(Sheet);
	SheetComponent->SetupAttachment(GetRootComponent());
	SheetComponent->SetAbsolute(true, true, true);
	SheetComponent->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	// The sheet carries the importer's frame like the tiles: the layers' scale and transform place it.
	if (Frame)
		SheetComponent->SetWorldTransform(FTransform(FQuat::Identity, FVector::ZeroVector, FVector(Frame->ImportedToUnreal())) * Frame->GetActorTransform());
	SheetComponent->RegisterComponent();
	UMaterialInstanceDynamic* Mid = nullptr;
	if (ChosenMaterial(Mid) && Mid)
		for (int32 Slot = 0; Slot < SheetComponent->GetNumMaterials(); ++Slot) SheetComponent->SetMaterial(Slot, Mid);
	else if (!Material) Status = FString::Printf(TEXT("'%s' is not one of the six presets: the sheet keeps its own material (assign yours in Material)."), *Look);
}

void AMarchingBlocksWater::DrawRebuilt()
{
	if (RebuiltComponent) { RebuiltComponent->DestroyComponent(); RebuiltComponent = nullptr; }
	if (!RebuiltSheet) return;
	RebuiltComponent = NewObject<UStaticMeshComponent>(this, NAME_None, RF_Transient);
	RebuiltComponent->SetStaticMesh(RebuiltSheet);
	RebuiltComponent->SetupAttachment(GetRootComponent());
	// Its vertices are already in the world (FormatToWorld): the component stays at the identity.
	RebuiltComponent->SetAbsolute(true, true, true);
	RebuiltComponent->SetWorldTransform(FTransform::Identity);
	RebuiltComponent->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	RebuiltComponent->RegisterComponent();
	UMaterialInstanceDynamic* Mid = nullptr;
	if (ChosenMaterial(Mid) && Mid) RebuiltComponent->SetMaterial(0, Mid);
}

void AMarchingBlocksWater::ShowRebuiltSheet(MBPaint::FWaterMesh&& Mesh, MBPaint::FCellSet&& Cells, const FString& Said)
{
	using namespace MarchingBlocksWaterDetail;
	RebuiltData = std::move(Mesh);
	WaterCells = std::move(Cells);
	bRebuilt = true;
	// An empty sheet still REPLACES the baked one: the water is gone.
	RebuiltSheet = RebuiltData.IsEmpty() ? nullptr : MakeSheet(this, RebuiltData, PlacingOf(FirstLayer(GetWorld(), WorldName, true)));
	if (SheetComponent) { SheetComponent->DestroyComponent(); SheetComponent = nullptr; }
	DrawRebuilt();
	Status = FString::Printf(TEXT("%s This layer: %d triangle(s)."), *Said, static_cast<int32>(RebuiltData.Indices.size() / 3));
}

void AMarchingBlocksWater::CompareWithBakedSheet()
{
	using namespace MarchingBlocksWaterDetail;
#if WITH_EDITORONLY_DATA
	if (!Sheet) { Status = TEXT("Compare: no baked sheet (Sheet)."); return; }
	if (!bRebuilt) { Status = TEXT("Compare: the water was not rebuilt yet — press Rebuild Water first."); return; }
	const FMeshDescription* Baked = Sheet->GetMeshDescription(0);
	AMarchingBlocksWorld* Frame = FirstLayer(GetWorld(), WorldName, true);
	if (!Baked || !Frame) { Status = TEXT("Compare: the baked sheet has no mesh description, or the world no layer."); return; }
	const FPlacing P = PlacingOf(Frame);
	const FTransform BakedToWorld = FTransform(FQuat::Identity, FVector::ZeroVector, FVector(Frame->ImportedToUnreal())) * Frame->GetActorTransform();
	// A triangle in the world: 3 corners of position (in cells), normal, colour.
	using FCmpTri = std::array<double, 30>;
	std::vector<FCmpTri> Want, Got;
	FStaticMeshConstAttributes BA(*Baked);
	const TVertexAttributesConstRef<FVector3f> BPos = BA.GetVertexPositions();
	const TVertexInstanceAttributesConstRef<FVector3f> BNor = BA.GetVertexInstanceNormals();
	const TVertexInstanceAttributesConstRef<FVector4f> BCol = BA.GetVertexInstanceColors();
	const double Cell = P.CellSize > 0.0 ? P.CellSize : 1.0;
	for (const FTriangleID T : Baked->Triangles().GetElementIDs())
	{
		TArrayView<const FVertexInstanceID> Corners = Baked->GetTriangleVertexInstances(T);
		FCmpTri Tri;
		for (int32 C = 0; C < 3; ++C)
		{
			const FVertexInstanceID I = Corners[C];
			const FVector Wp = BakedToWorld.TransformPosition(FVector(BPos[Baked->GetVertexInstanceVertex(I)]));
			const FVector Nn = BakedToWorld.TransformVectorNoScale(FVector(BNor[I])).GetSafeNormal();
			const FVector4f Co = BCol.IsValid() ? BCol[I] : FVector4f(1, 1, 1, 1);
			double* D = &Tri[static_cast<size_t>(C) * 10];
			D[0] = Wp.X / Cell; D[1] = Wp.Y / Cell; D[2] = Wp.Z / Cell;
			D[3] = Nn.X; D[4] = Nn.Y; D[5] = Nn.Z;
			// Back to the contract's values (what the presets read): the importer linearised r, g, b.
			D[6] = LinearToSrgb(Co.X); D[7] = LinearToSrgb(Co.Y); D[8] = LinearToSrgb(Co.Z); D[9] = Co.W;
		}
		Want.push_back(Tri);
	}
	for (size_t K = 0; K + 2 < RebuiltData.Indices.size(); K += 3)
	{
		const uint32 Corner[3] = {RebuiltData.Indices[K], P.bTurn ? RebuiltData.Indices[K + 2] : RebuiltData.Indices[K + 1],
			P.bTurn ? RebuiltData.Indices[K + 1] : RebuiltData.Indices[K + 2]};
		FCmpTri Tri;
		for (int32 C = 0; C < 3; ++C)
		{
			const MBPaint::FWaterVertex& V = RebuiltData.Vertices[Corner[C]];
			const FVector3f Wp = PosOf(P, V);
			const FVector3f Nn = NormalOf(P, V);
			double* D = &Tri[static_cast<size_t>(C) * 10];
			D[0] = Wp.X / Cell; D[1] = Wp.Y / Cell; D[2] = Wp.Z / Cell;
			D[3] = Nn.X; D[4] = Nn.Y; D[5] = Nn.Z;
			for (int32 X = 0; X < 4; ++X) D[6 + X] = V.Color[X];
		}
		Got.push_back(Tri);
	}
	// The bag: buckets by centroid (0.01 cell), rotations only — a reflected triangle is counted apart.
	auto KeyOf = [](const FCmpTri& Q)
	{
		return std::array<int64, 3>{FMath::RoundToInt64((Q[0] + Q[10] + Q[20]) * 100.0 / 3.0), FMath::RoundToInt64((Q[1] + Q[11] + Q[21]) * 100.0 / 3.0),
			FMath::RoundToInt64((Q[2] + Q[12] + Q[22]) * 100.0 / 3.0)};
	};
	std::map<std::array<int64, 3>, std::vector<size_t>> Buckets;
	for (size_t I = 0; I < Got.size(); ++I) Buckets[KeyOf(Got[I])].push_back(I);
	std::vector<bool> Taken(Got.size(), false);
	// Positions: a horizon 2 000 cells away, kept in 32-bit centimetres, is good to ~2e-4 cell.
	auto Near = [](const FCmpTri& Ta, int32 Ca, const FCmpTri& Tb, int32 Cb)
	{
		const double* X = &Ta[static_cast<size_t>(Ca) * 10];
		const double* Y = &Tb[static_cast<size_t>(Cb) * 10];
		for (int32 I = 0; I < 6; ++I) if (FMath::Abs(X[I] - Y[I]) > 2e-3) return false;
		for (int32 I = 6; I < 10; ++I) if (FMath::Abs(X[I] - Y[I]) > 1.0 / 255.0 + 1e-5) return false;
		return true;
	};
	int32 Same = 0, Reflected = 0, Missing = 0;
	FString Nearest;
	for (const FCmpTri& Tw : Want)
	{
		const std::array<int64, 3> K0 = KeyOf(Tw);
		int32 Found = 0;
		for (int64 Dx = -1; Dx <= 1 && !Found; ++Dx)
			for (int64 Dy = -1; Dy <= 1 && !Found; ++Dy)
				for (int64 Dz = -1; Dz <= 1 && !Found; ++Dz)
				{
					const auto Bucket = Buckets.find({K0[0] + Dx, K0[1] + Dy, K0[2] + Dz});
					if (Bucket == Buckets.end()) continue;
					for (size_t I : Bucket->second)
					{
						if (Taken[I]) continue;
						for (int32 R = 0; R < 3 && !Found; ++R)
						{
							if (Near(Tw, 0, Got[I], R) && Near(Tw, 1, Got[I], (R + 1) % 3) && Near(Tw, 2, Got[I], (R + 2) % 3)) Found = 1;
							else if (Near(Tw, 0, Got[I], R) && Near(Tw, 1, Got[I], (R + 2) % 3) && Near(Tw, 2, Got[I], (R + 1) % 3)) Found = 2;
						}
						if (Found) { Taken[I] = true; break; }
					}
				}
		if (Found == 1) ++Same;
		else if (Found == 2) ++Reflected;
		else
		{
			++Missing;
			if (Nearest.IsEmpty())
			{
				// The first one without a match: the nearest of ours (positions, any order of corners), and by how much.
				double Best = 1e30, D[3] = {0, 0, 0};
				for (const FCmpTri& G : Got)
					for (int32 R = 0; R < 3; ++R)
						for (int32 Flip = 0; Flip < 2; ++Flip)
						{
							double E[3] = {0, 0, 0};
							for (int32 C = 0; C < 3; ++C)
							{
								const int32 O = Flip ? (R + 3 - C) % 3 : (R + C) % 3;
								for (int32 I = 0; I < 10; ++I)
								{
									const int32 Gi = I < 3 ? 0 : I < 6 ? 1 : 2;
									E[Gi] = FMath::Max(E[Gi], FMath::Abs(Tw[static_cast<size_t>(C * 10 + I)] - G[static_cast<size_t>(O * 10 + I)]));
								}
							}
							if (E[0] < Best) { Best = E[0]; D[0] = E[0]; D[1] = E[1]; D[2] = E[2]; }
						}
				Nearest = FString::Printf(TEXT(" First without a match: baked corner (%.3f %.3f %.3f) normal (%.3f %.3f %.3f) colour (%.3f %.3f %.3f %.3f); the nearest rebuilt differs by position %.2g cell, normal %.2g, colour %.2g."),
					Tw[0], Tw[1], Tw[2], Tw[3], Tw[4], Tw[5], Tw[6], Tw[7], Tw[8], Tw[9], D[0], D[1], D[2]);
			}
		}
	}
	const bool bSame = Want.size() == Got.size() && Same == static_cast<int32>(Want.size());
	Status = FString::Printf(TEXT("Compare: %s — baked %d triangles, rebuilt %d; %d the same, %d reflected (turned the other way), %d without a match."),
		bSame ? TEXT("THE SAME SHEET") : TEXT("DIFFERENT"), static_cast<int32>(Want.size()), static_cast<int32>(Got.size()), Same, Reflected, Missing);
	Status += Nearest;
	UE_LOG(LogMarchingBlocksWater, Display, TEXT("%s: %s"), *GetName(), *Status);
#else
	Status = TEXT("Compare: in the editor only.");
#endif
}

// ── The follow ────────────────────────────────────────────────────────────────────────────────────────

void AMarchingBlocksWater::NoteWorldEdited(UWorld* World, FName InWorldName)
{
	using namespace MarchingBlocksWaterDetail;
	if (!World || WaterLayers(World, InWorldName).Num() == 0) return;
	const TSharedPtr<FFollow> F = FollowOf(World, InWorldName, true);
	EnsureTicker();
	if (F->bBusy) { F->bAgain = true; return; }
	F->bStale = true;
	F->Due = FPlatformTime::Seconds() + Calm();
	if (!F->bAuto)
		for (AMarchingBlocksWater* W : WaterLayers(World, InWorldName))
			W->Status = FString::Printf(TEXT("STALE — the water no longer follows by itself (the last rebuild took %.2f s): press Rebuild Water."), F->LastSeconds);
}

void AMarchingBlocksWater::SetGestureOpen(bool bOpen)
{
	using namespace MarchingBlocksWaterDetail;
	if (bGestureOpen == bOpen) return;
	bGestureOpen = bOpen;
	// The end of a gesture: half a second of calm from now.
	if (!bOpen)
		for (const TSharedPtr<FFollow>& F : Follows)
			if (F->bStale) F->Due = FPlatformTime::Seconds() + Calm();
}

bool AMarchingBlocksWater::RebuildWorldWater(UWorld* World, FName InWorldName)
{
	using namespace MarchingBlocksWaterDetail;
	if (!World || WaterLayers(World, InWorldName).Num() == 0) return false;
	const TSharedPtr<FFollow> F = FollowOf(World, InWorldName, true);
	EnsureTicker();
	F->bManualWanted = true;
	if (F->bBusy) { F->bAgain = true; return true; }
	F->bStale = true;
	F->Due = 0.0;
	if (!bGestureOpen) Launch(F, true);
	return true;
}

FString AMarchingBlocksWater::FollowStatus(UWorld* World, FName InWorldName)
{
	using namespace MarchingBlocksWaterDetail;
	if (!World || WaterLayers(World, InWorldName).Num() == 0) return FString();
	const TSharedPtr<FFollow> F = FollowOf(World, InWorldName, false);
	if (!F) return TEXT("Water: the baked sheet (paint, and it follows).");
	if (F->bBusy) return TEXT("Water: rebuilding…");
	if (F->bStale) return F->bAuto ? TEXT("Water: stale — rebuilt half a second after the last gesture.")
		: TEXT("Water: STALE — the automatic follow is off (the last rebuild was too long): press Rebuild Water.");
	return F->LastSaid;
}

bool AMarchingBlocksWater::IsRebuildPending(UWorld* World, FName InWorldName)
{
	using namespace MarchingBlocksWaterDetail;
	const TSharedPtr<FFollow> F = FollowOf(World, InWorldName, false);
	return F && (F->bBusy || F->bAgain || (F->bStale && (F->bAuto || F->bManualWanted)));
}

void AMarchingBlocksWater::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	DrawSheet();
	RecomputeWater();
}

#if WITH_EDITOR
void AMarchingBlocksWater::PostEditChangeProperty(FPropertyChangedEvent& Event)
{
	Super::PostEditChangeProperty(Event);
	DrawSheet();
	RecomputeWater();
	// New sources, another order or another world: the water is stale (a look or a material is only drawn again).
	const FName Name = Event.GetMemberPropertyName();
	if (Name == GET_MEMBER_NAME_CHECKED(AMarchingBlocksWater, Sources) || Name == GET_MEMBER_NAME_CHECKED(AMarchingBlocksWater, Order)
		|| Name == GET_MEMBER_NAME_CHECKED(AMarchingBlocksWater, WorldName))
		NoteWorldEdited(GetWorld(), WorldName);
}

void AMarchingBlocksWater::PostEditUndo()
{
	Super::PostEditUndo();
	NoteWorldEdited(GetWorld(), WorldName);
}
#endif
