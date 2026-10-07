// MarchingBlocks Paint for Unreal — les opérations d'édition (voir MBEditing.h). Réécrites depuis la règle du cœur
// (`etages.gd`, `extruder` ; `outils.gd`, `retrecir_bord`, `elargir_a_plat`, `selectionner_au_pinceau`) et son
// rules_text ; éprouvées par Tests/editing_conformance.json.
//
// ⚠ Préfixe Edt… : les « unity builds » d'Unreal fusionnent les .cpp, deux fonctions locales homonymes s'y heurtent.

#include "MBCore/MBEditing.h"

namespace MBPaint
{
	namespace
	{
		// L'ordre départage une égalité de « face » : le haut d'abord, comme dans l'appli.
		const FCell EdtSixSteps[6] = {FCell(0, 1, 0), FCell(0, -1, 0), FCell(1, 0, 0), FCell(-1, 0, 0), FCell(0, 0, 1), FCell(0, 0, -1)};
		const FCell EdtFaces[6] = {FCell(1, 0, 0), FCell(-1, 0, 0), FCell(0, 1, 0), FCell(0, -1, 0), FCell(0, 0, 1), FCell(0, 0, -1)};
		const FCell EdtFlat[4] = {FCell(1, 0, 0), FCell(-1, 0, 0), FCell(0, 0, 1), FCell(0, 0, -1)};

		// La portée de « face » : la sélection si elle existe, sinon l'étage.
		bool EdtInScope(const FCell& P, int Floor, const FCellSet& Scope)
		{
			return Scope.empty() ? P.Y == Floor : Scope.count(P) > 0;
		}
	}

	namespace Editing
	{
		FCell FacingStep(const FCellSet& Cells, int Floor, const FCellSet& Selection)
		{
			FCell Best;
			size_t BestCount = 0;
			for (const FCell& D : EdtSixSteps)
			{
				size_t N = 0;
				for (const FCell& P : Cells)
					if (EdtInScope(P, Floor, Selection) && !Cells.count(P + D) && Cells.count(P - D)) ++N;
				if (N > BestCount) { BestCount = N; Best = D; }
			}
			return Best;
		}

		FExtrudeResult Extrude(const FCellSet& Cells, int Floor, EExtrudeDirection Direction, const FCellSet& Selection,
			EExtrudeMode Mode)
		{
			FExtrudeResult R;
			R.Selection = Selection;
			FCellSet FloorBase;
			if (Selection.empty())
				for (const FCell& C : Cells)
					if (C.Y == Floor) FloorBase.insert(C);
			const FCellSet& Base = Selection.empty() ? FloorBase : Selection;
			FCell Step;
			if (Direction == EExtrudeDirection::Up) Step = FCell(0, 1, 0);
			else if (Direction == EExtrudeDirection::Down) Step = FCell(0, -1, 0);
			else Step = FacingStep(Cells, Floor, Selection);
			if (Step.IsZero() || Base.empty()) return R;
			R.Step = Step;
			FCellSet Shifted;
			for (const FCell& C : Base) Shifted.insert(C + Step);
			if (Mode == EExtrudeMode::Extend)
			{
				R.Selection = Base;
				R.Selection.insert(Shifted.begin(), Shifted.end());
			}
			else if (Mode == EExtrudeMode::Shift) R.Selection = Shifted;
			else
			{
				for (const FCell& C : Base)
					if (Cells.count(C) && !Cells.count(C + Step)) R.Set.insert(C + Step);
				R.Selection = Selection.empty() ? FCellSet() : Shifted;
			}
			return R;
		}

		FCellSet ShrinkEdge(const FCellSet& Selection)
		{
			FCellSet Out;
			for (const FCell& C : Selection)
			{
				bool bEdge = false;
				for (const FCell& F : EdtFaces)
					if (Selection.count(C - F) && !Selection.count(C + F)) { bEdge = true; break; }
				if (!bEdge) Out.insert(C);
			}
			return Out;
		}

		FCellSet WidenFlat(const FCellSet& Selection)
		{
			FCellSet Out;
			for (const FCell& C : Selection)
			{
				Out.insert(C);
				for (const FCell& D : EdtFlat) Out.insert(C + D);
			}
			return Out;
		}

		void SelectBrush(FCellSet& Selection, const std::vector<FCell>& Targets, const FIsFull& IsFull, bool bIncludeEmpty,
			bool bDeselect)
		{
			for (const FCell& C : Targets)
			{
				if (bDeselect) Selection.erase(C);
				else if (bIncludeEmpty || IsFull(C)) Selection.insert(C);
			}
		}
	}
}
