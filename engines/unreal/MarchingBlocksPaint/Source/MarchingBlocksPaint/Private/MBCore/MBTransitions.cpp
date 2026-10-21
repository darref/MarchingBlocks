// MarchingBlocks Paint for Unreal — les transitions entre couches (voir MBTransitions.h). Réécrites depuis la règle du
// cœur (`transitions.gd` : `melange`, `_visible`, `table`, `reglages`, `construire` ; `format_monde.gd`,
// `lire_transitions`) ; éprouvées par Tests/transitions_conformance.json.
//
// ⚠ Préfixe Trn… (les « unity builds » d'Unreal fusionnent les .cpp).

#include "MBCore/MBTransitions.h"

#include <algorithm>
#include <climits>

namespace MBPaint
{
	namespace
	{
		struct FTrnKey
		{
			const char* Name;
			double FTransitionSettings::*Member;
			double Lo;
			double Hi;
		};

		const FTrnKey TrnKeys[5] = {
			{"softness", &FTransitionSettings::Softness, 0.05, 1.0},
			{"reach", &FTransitionSettings::Reach, -0.5, 0.5},
			{"irregularity", &FTransitionSettings::Irregularity, 0.0, 1.0},
			{"grain", &FTransitionSettings::Grain, 0.25, 6.0},
			{"fills_hollows", &FTransitionSettings::FillsHollows, 0.0, 1.0},
		};

		double TrnClamp(double X, double Lo, double Hi) { return std::max(Lo, std::min(Hi, X)); }

		double TrnWeight(int K, const double F[3])
		{
			return ((K & 1) ? F[0] : 1.0 - F[0]) * (((K >> 1) & 1) ? F[1] : 1.0 - F[1]) * (((K >> 2) & 1) ? F[2] : 1.0 - F[2]);
		}

		double TrnSmoothstep(double E0, double E1, double X)
		{
			const double T = TrnClamp((X - E0) / (E1 - E0), 0.0, 1.0);
			return T * T * (3.0 - 2.0 * T);
		}

		// La part VISIBLE de la couvrante (sa part de cases SC, H la hauteur de la couverte) : le décalage est nul aux bouts.
		double TrnVisible(const FTransitionSettings& R, double SC, double H, double N)
		{
			const double Shift = (R.Reach + R.FillsHollows * (0.5 - H) + R.Irregularity * (N - 0.5)) * 4.0 * SC * (1.0 - SC);
			return TrnSmoothstep(0.5 - R.Softness * 0.5, 0.5 + R.Softness * 0.5, SC + Shift);
		}

		uint8_t TrnByte(int Rank) { return static_cast<uint8_t>(Rank >= 0 && Rank < Transitions::LayersMax ? Rank + 1 : 0); }

		bool TrnLess(const FCell& A, const FCell& B) { return A < B; }
	}

	int64_t FCellTexture::IndexOf(const FCell& C) const
	{
		const FCell T = C - Origin;
		if (T.X < 0 || T.Y < 0 || T.Z < 0 || T.X >= Size.X || T.Y >= Size.Y || T.Z >= Size.Z) return -1;
		return (static_cast<int64_t>(T.Z) * Size.Y + T.Y) * Size.X + T.X;
	}

	namespace Transitions
	{
		FTransitionSettings ReadSettings(const FJsonValue& Value)
		{
			FTransitionSettings S;
			for (const FTrnKey& K : TrnKeys)
			{
				const FJsonValue* X = Value.Find(K.Name);
				const double V = X && X->IsNumber() ? X->AsReal() : S.*K.Member;
				S.*K.Member = TrnClamp(V, K.Lo, K.Hi);
			}
			return S;
		}

		FJsonValue SettingsToJson(const FTransitionSettings& S)
		{
			FJsonValue Out = FJsonValue::MakeObject();
			for (const FTrnKey& K : TrnKeys) Out.Set(K.Name, FJsonValue::MakeReal(S.*K.Member));
			return Out;
		}

		std::string Read(const FJsonValue& World, FTransitions& Out)
		{
			Out = FTransitions();
			if (World.Type != FJsonValue::EType::Object) return "not a MarchingBlocks world";
			const FJsonValue& Layers = World["layers"];
			const int64_t LayerCount = Layers.Type == FJsonValue::EType::Array ? static_cast<int64_t>(Layers.Size()) : 0;
			const FJsonValue* T = World.Find("transitions");
			if (!T || T->IsNull()) return "";
			if (T->Type != FJsonValue::EType::Object) return "transitions is not an object";
			FTransitions R;
			const FJsonValue* Pairs = T->Find("pairs");
			if (Pairs && Pairs->Type != FJsonValue::EType::Array) return "transitions: pairs is not an array";
			if (Pairs)
				for (const FJsonValue& P : Pairs->Array)
				{
					if (P.Type != FJsonValue::EType::Object || !P["a"].IsWhole() || !P["b"].IsWhole() || P["active"].Type != FJsonValue::EType::Bool)
						return "transitions: a pair has no layers a, b or no active";
					const double A = P["a"].AsReal(), B = P["b"].AsReal();
					if (A < 0 || B >= static_cast<double>(LayerCount) || A >= B) return "transitions: a pair is not two layers a < b";
					FTransitionPair Pair;
					Pair.A = static_cast<int>(A);
					Pair.B = static_cast<int>(B);
					for (const FTransitionPair& Seen : R.Pairs)
						if (Seen.A == Pair.A && Seen.B == Pair.B) return "transitions: a pair appears twice";
					Pair.bActive = P["active"].Bool;
					const char* Directions[2] = {"a_covers_b", "b_covers_a"};
					for (int D = 0; D < 2; ++D)
					{
						const FJsonValue& S = P[Directions[D]];
						if (S.Type != FJsonValue::EType::Object) return std::string("transitions: a pair has no ") + Directions[D];
						for (const auto& Entry : S.Object)
							if (!Entry.second.IsNumber()) return "transitions: a setting of a pair is not a number";
						(D == 0 ? Pair.ACoversB : Pair.BCoversA) = ReadSettings(S);
					}
					R.Pairs.push_back(Pair);
				}
			const FJsonValue& Reps = (*T)["representatives"];
			if (Reps.Type != FJsonValue::EType::Array || static_cast<int64_t>(Reps.Size()) != LayerCount)
				return "transitions: representatives is not one per layer";
			for (const FJsonValue& E : Reps.Array)
			{
				if (E.Type != FJsonValue::EType::Object || !(E["image"].IsNull() || E["image"].Type == FJsonValue::EType::String))
					return "transitions: a representative's image is neither a path nor null";
				const FJsonValue& C = E["color"];
				if (C.Type != FJsonValue::EType::Array || C.Size() != 4) return "transitions: a representative's color is not four numbers";
				for (const FJsonValue& X : C.Array)
					if (!X.IsNumber()) return "transitions: a representative's color is not four numbers";
				if (!E["scale"].IsNumber() || !E["roughness"].IsNumber())
					return "transitions: a representative's scale or roughness is not a number";
				FRepresentative Rep;
				Rep.bHasImage = E["image"].Type == FJsonValue::EType::String;
				Rep.Image = E["image"].String;
				for (size_t I = 0; I < 4; ++I) Rep.Color[I] = C[I].AsReal();
				Rep.Scale = std::max(E["scale"].AsReal(), 0.01);
				Rep.Roughness = TrnClamp(E["roughness"].AsReal(), 0.0, 1.0);
				R.Representatives.push_back(Rep);
			}
			const FJsonValue* Flat = T->Find("choices");
			if (Flat && (Flat->Type != FJsonValue::EType::Array || Flat->Size() % 4 != 0))
				return "transitions: choices is not a list of x y z L";
			if (Flat)
				for (size_t I = 0; I < Flat->Size(); I += 4)
				{
					for (size_t J = 0; J < 4; ++J)
						if (!(*Flat)[I + J].IsWhole()) return "transitions: a choice is not made of integers";
					const FCell V(static_cast<int>((*Flat)[I].AsInt()), static_cast<int>((*Flat)[I + 1].AsInt()), static_cast<int>((*Flat)[I + 2].AsInt()));
					for (const auto& Seen : R.Choices)
						if (Seen.first == V) return "transitions: a vertex is chosen twice";
					const int64_t L = (*Flat)[I + 3].AsInt();
					if (L < 0 || L >= LayerCount) return "transitions: a choice names a layer that does not exist";
					R.Choices.push_back({V, static_cast<int>(L)});
				}
			std::sort(R.Choices.begin(), R.Choices.end(),
				[](const std::pair<FCell, int>& X, const std::pair<FCell, int>& Y) { return TrnLess(X.first, Y.first); });
			Out = R;
			return "";
		}

		FJsonValue ToJson(const FTransitions& T)
		{
			FJsonValue Pairs = FJsonValue::MakeArray();
			for (const FTransitionPair& P : T.Pairs)
			{
				FJsonValue E = FJsonValue::MakeObject();
				E.Set("a", FJsonValue::MakeInt(P.A)).Set("b", FJsonValue::MakeInt(P.B)).Set("active", FJsonValue::MakeBool(P.bActive))
					.Set("a_covers_b", SettingsToJson(P.ACoversB)).Set("b_covers_a", SettingsToJson(P.BCoversA));
				Pairs.Push(E);
			}
			FJsonValue Reps = FJsonValue::MakeArray();
			for (const FRepresentative& R : T.Representatives)
			{
				FJsonValue E = FJsonValue::MakeObject();
				FJsonValue C = FJsonValue::MakeArray();
				for (double X : R.Color) C.Push(FJsonValue::MakeReal(X));
				E.Set("image", R.bHasImage ? FJsonValue::MakeString(R.Image) : FJsonValue()).Set("color", C)
					.Set("scale", FJsonValue::MakeReal(R.Scale)).Set("roughness", FJsonValue::MakeReal(R.Roughness));
				Reps.Push(E);
			}
			FJsonValue Choices = FJsonValue::MakeArray();
			for (const auto& C : T.Choices)
			{
				FJsonValue E = FJsonValue::MakeArray();
				E.Push(FJsonValue::MakeInt(C.first.X)).Push(FJsonValue::MakeInt(C.first.Y)).Push(FJsonValue::MakeInt(C.first.Z))
					.Push(FJsonValue::MakeInt(C.second));
				Choices.Push(E);
			}
			FJsonValue Out = FJsonValue::MakeObject();
			Out.Set("pairs", Pairs).Set("representatives", Reps).Set("choices", Choices);
			return Out;
		}

		FTransitionTable Table(const std::vector<FTransitionPair>& Pairs, int LayerCount)
		{
			FTransitionTable Out;
			for (const FTransitionPair& P : Pairs)
			{
				if (!P.bActive || P.A < 0 || P.B < 0 || P.A >= LayerCount || P.B >= LayerCount) continue;
				if (P.A >= LayersMax || P.B >= LayersMax) continue;
				Out[{P.A, P.B}] = P.ACoversB;
				Out[{P.B, P.A}] = P.BCoversA;
			}
			return Out;
		}

		FBlend Blend(const int Ranks[8], const double F[3], const int Choices[8], const FTransitionTable& Table,
			const std::map<int, double>& H, double N)
		{
			FBlend R;
			int Owner = INT_MAX;
			for (int K = 0; K < 8; ++K)
				if (Ranks[K] >= 0 && Ranks[K] < Owner) Owner = Ranks[K];
			if (Owner == INT_MAX) return R;
			double WOwner = 0.0;
			std::map<int, double> Parts;
			for (int K = 0; K < 8; ++K)
			{
				if (Ranks[K] < 0) continue;
				if (Ranks[K] == Owner) WOwner += TrnWeight(K, F);
				else Parts[Ranks[K]] += TrnWeight(K, F);
			}
			// Le départage du shader : les coins dans l'ordre, la première part STRICTEMENT plus grande l'emporte.
			int Other = -1;
			double Best = 0.0;
			for (int K = 0; K < 8; ++K)
				if (Ranks[K] >= 0 && Ranks[K] != Owner && Parts[Ranks[K]] > Best)
				{
					Best = Parts[Ranks[K]];
					Other = Ranks[K];
				}
			if (Other < 0) return R;
			const auto OtherCovers = Table.find({Other, Owner});
			const auto OwnerCovers = Table.find({Owner, Other});
			if (OtherCovers == Table.end() || OwnerCovers == Table.end()) return R;
			const double S = Best / (Best + WOwner);
			const int First = std::min(Owner, Other);
			double Vote = 0.0;
			for (int K = 0; K < 8; ++K)
			{
				const int Covering = Choices[K] == Owner || Choices[K] == Other ? Choices[K] : First;
				if (Covering == Other) Vote += TrnWeight(K, F);
			}
			const auto HOwner = H.find(Owner);
			const auto HOther = H.find(Other);
			const double AOther = TrnVisible(OtherCovers->second, S, HOwner == H.end() ? 0.5 : HOwner->second, N);
			const double AOwner = 1.0 - TrnVisible(OwnerCovers->second, 1.0 - S, HOther == H.end() ? 0.5 : HOther->second, N);
			R.bDrawn = true;
			R.Owner = Owner;
			R.Other = Other;
			R.S = S;
			R.Vote = Vote;
			R.Alpha = Vote * AOther + (1.0 - Vote) * AOwner;
			return R;
		}

		FCellTexture BuildCellTexture(const std::vector<std::pair<FCell, int>>& Cells, const std::vector<std::pair<FCell, int>>& Choices)
		{
			FCellTexture D;
			if (Cells.empty())
			{
				D.Bytes.assign(2, 0);
				return D;
			}
			FCell Lo(INT_MAX, INT_MAX, INT_MAX), Hi(INT_MIN, INT_MIN, INT_MIN);
			for (const auto& C : Cells)
			{
				Lo = FCell(std::min(Lo.X, C.first.X), std::min(Lo.Y, C.first.Y), std::min(Lo.Z, C.first.Z));
				Hi = FCell(std::max(Hi.X, C.first.X), std::max(Hi.Y, C.first.Y), std::max(Hi.Z, C.first.Z));
			}
			D.Origin = Lo - FCell(Margin, Margin, Margin);
			D.Size = Hi - Lo + FCell(2 * Margin + 1, 2 * Margin + 1, 2 * Margin + 1);
			D.Bytes.assign(2 * static_cast<size_t>(D.Size.X) * static_cast<size_t>(D.Size.Y) * static_cast<size_t>(D.Size.Z), 0);
			for (const auto& C : Cells) D.Bytes[2 * static_cast<size_t>(D.IndexOf(C.first))] = TrnByte(C.second);
			for (const auto& C : Choices)
			{
				const int64_t I = D.IndexOf(C.first);
				if (I < 0) continue;
				D.Bytes[2 * static_cast<size_t>(I) + 1] = TrnByte(C.second);
			}
			return D;
		}
	}
}
