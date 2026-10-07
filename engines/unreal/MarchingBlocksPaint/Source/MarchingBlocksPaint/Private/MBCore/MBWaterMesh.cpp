// MarchingBlocks Paint for Unreal — la nappe d'eau (voir MBWaterMesh.h). Réécrite depuis `eau_maillage.gd`, LIGNE À LIGNE
// (`tableaux_du_maillage`, `_nappes_du_corps`, `rectangles_de_nappe`, `surface_dessinee`, `_large`, `_riviere`,
// `sens_du_cours`, `_lame`, `_poser_les_lames`, `_lame_calculee`, `_travers`, `_chutes`, `_sortie`, `_profil`, `_devant`,
// `_point_de_lame`, `_normale_de_lame`, `_couronne`, `_source`, `_grille_compilee`, `_poser`, `_quad`, `_plat`,
// `_case_plate`, `_poser_les_plats`). Éprouvée par Tests/water_mesh_conformance.json (14 cas, un SAC de triangles).
//
// ⚠ LES FLOTTANTS COMME GODOT : les scalaires en double (GDScript), les Vector3 / Color / Vector2 en 32 bits — un point de
// cascade est calculé en double puis rangé en float ; sa normale vient de différences de ces points 32 bits, en
// arithmétique 32 bits (Vector3 de Godot) ; les chutes d'une cascade sont un PackedFloat32Array. Les tolérances des cas
// (1e-4, normale 1e-3) le couvriraient sans doute en double partout ; on n'en a pas besoin pour être sûr.
// ⚠ L'ORDRE DES TRIANGLES n'est pas le contrat (un sac) ; on garde pourtant celui de l'appli (cascades, plats, écume en
// dernier : la transparence en dépend), et ses triangles HORAIRES (Godot) sont retournés à la fin : le format est
// anti-horaire (glTF).
// ⚠ Le cœur privé de l'appli (`eau_poser_les_plats`, gdextension/src/appli/eau.cpp) n'est PAS ici : `_poser_les_plats`
// est réécrit depuis le GDScript, qui reste la référence.
// ⚠ Préfixe Wm… (les « unity builds » d'Unreal fusionnent les .cpp).

#include "MBCore/MBWaterMesh.h"

#include <algorithm>
#include <cmath>
#include <map>
#include <tuple>
#include <unordered_map>

namespace MBPaint
{
	namespace
	{
		using namespace WaterMesh;

		const FCell WmUp(0, 1, 0);
		const FCell WmDown(0, -1, 0);
		const FCell WmHorizontal[4] = {FCell(1, 0, 0), FCell(-1, 0, 0), FCell(0, 0, 1), FCell(0, 0, -1)};
		constexpr double WmTau = 6.28318530717958647692;

		// Un Vector3 de Godot : 32 bits, arithmétique 32 bits.
		struct FWmV3
		{
			float X = 0.f, Y = 0.f, Z = 0.f;
			FWmV3() = default;
			FWmV3(float InX, float InY, float InZ) : X(InX), Y(InY), Z(InZ) {}
			static FWmV3 D(double InX, double InY, double InZ)
			{
				return FWmV3(static_cast<float>(InX), static_cast<float>(InY), static_cast<float>(InZ));
			}
			FWmV3 operator+(const FWmV3& O) const { return FWmV3(X + O.X, Y + O.Y, Z + O.Z); }
			FWmV3 operator-(const FWmV3& O) const { return FWmV3(X - O.X, Y - O.Y, Z - O.Z); }
			FWmV3 operator*(float S) const { return FWmV3(X * S, Y * S, Z * S); }
		};

		FWmV3 WmCross(const FWmV3& A, const FWmV3& B)
		{
			return FWmV3(A.Y * B.Z - A.Z * B.Y, A.Z * B.X - A.X * B.Z, A.X * B.Y - A.Y * B.X);
		}

		float WmDot(const FWmV3& A, const FWmV3& B) { return A.X * B.X + A.Y * B.Y + A.Z * B.Z; }
		float WmLength(const FWmV3& A) { return std::sqrt(A.X * A.X + A.Y * A.Y + A.Z * A.Z); }

		FWmV3 WmNormalized(const FWmV3& A)
		{
			const float L2 = A.X * A.X + A.Y * A.Y + A.Z * A.Z;
			if (L2 == 0.f) return FWmV3();
			const float L = std::sqrt(L2);
			return FWmV3(A.X / L, A.Y / L, A.Z / L);
		}

		struct FWmColor
		{
			float R = 0.f, G = 0.f, B = 0.f, A = 0.f;
			bool operator==(const FWmColor& O) const { return R == O.R && G == O.G && B == O.B && A == O.A; }
			bool operator<(const FWmColor& O) const { return std::tie(R, G, B, A) < std::tie(O.R, O.G, O.B, O.A); }
		};

		struct FWmUV
		{
			float U = 0.f, V = 0.f;
		};

		double WmClamp(double V, double Lo, double Hi) { return V < Lo ? Lo : (V > Hi ? Hi : V); }

		// `_couleur` : le courant ramené de [−1, 1] à [0, 1], le genre, la profondeur (ou l'écume) bornée à [0, 1].
		FWmColor WmColorOf(double FlowX, double FlowZ, double Kind, double Amount)
		{
			FWmColor C;
			C.R = static_cast<float>(FlowX * 0.5 + 0.5);
			C.G = static_cast<float>(FlowZ * 0.5 + 0.5);
			C.B = static_cast<float>(Kind);
			C.A = static_cast<float>(WmClamp(Amount, 0.0, 1.0));
			return C;
		}

		// Les tableaux de Godot ({v, n, c, uv, i}), triangles HORAIRES comme `_quad` et `_grille_compilee` les rangent.
		struct FWmArrays
		{
			std::vector<FWmV3> V, N;
			std::vector<FWmColor> C;
			std::vector<FWmUV> UV;
			std::vector<uint32_t> I;
			uint32_t Size() const { return static_cast<uint32_t>(V.size()); }
			void Add(const FWmV3& P, const FWmV3& Nn, const FWmColor& Cc, const FWmUV& T)
			{
				V.push_back(P);
				N.push_back(Nn);
				C.push_back(Cc);
				UV.push_back(T);
			}
		};

		// Une grille de sommets (rangées de même longueur), avant compilation.
		struct FWmGrid
		{
			std::vector<std::vector<FWmV3>> P, N;
			std::vector<std::vector<FWmColor>> C;
			std::vector<std::vector<FWmUV>> UV;
		};

		// `_grille_compilee` : les triangles de la grille (chacun tourné d'après la normale de son PREMIER coin, sans aire :
		// pas posé), puis les sommets qu'aucun triangle n'emploie retirés.
		FWmArrays WmCompile(const FWmGrid& G)
		{
			FWmArrays Out;
			const size_t Rows = G.P.size();
			if (Rows < 2) return Out;
			const size_t Cols = G.P[0].size();
			std::vector<FWmV3> V, Ns;
			std::vector<FWmColor> Cs;
			std::vector<FWmUV> UVs;
			for (size_t R = 0; R < Rows; ++R)
				for (size_t J = 0; J < Cols; ++J)
				{
					V.push_back(G.P[R][J]);
					Ns.push_back(G.N[R][J]);
					Cs.push_back(G.C[R][J]);
					UVs.push_back(G.UV[R][J]);
				}
			std::vector<uint32_t> Idx;
			for (size_t R = 0; R + 1 < Rows; ++R)
				for (size_t J = 0; J + 1 < Cols; ++J)
				{
					const uint32_t K[4] = {static_cast<uint32_t>(R * Cols + J), static_cast<uint32_t>(R * Cols + J + 1),
						static_cast<uint32_t>((R + 1) * Cols + J + 1), static_cast<uint32_t>((R + 1) * Cols + J)};
					const uint32_t T[2][3] = {{K[0], K[1], K[2]}, {K[0], K[2], K[3]}};
					for (const auto& Tri : T)
					{
						const FWmV3 X = WmCross(V[Tri[1]] - V[Tri[0]], V[Tri[2]] - V[Tri[0]]);
						if (WmLength(X) < 1e-7f) continue;
						if (WmDot(X, Ns[Tri[0]]) > 0.f) Idx.insert(Idx.end(), {Tri[0], Tri[2], Tri[1]});
						else Idx.insert(Idx.end(), {Tri[0], Tri[1], Tri[2]});
					}
				}
			std::vector<int64_t> New(V.size(), -1);
			for (uint32_t K : Idx) New[K] = 0;
			uint32_t Kept = 0;
			for (size_t K = 0; K < V.size(); ++K)
				if (New[K] == 0)
				{
					New[K] = Kept++;
					Out.Add(V[K], Ns[K], Cs[K], UVs[K]);
				}
			for (uint32_t K : Idx) Out.I.push_back(static_cast<uint32_t>(New[K]));
			return Out;
		}

		// `_poser` : une grille compilée, ses indices décalés du nombre de sommets déjà posés.
		void WmPose(FWmArrays& A, const FWmArrays& G)
		{
			const uint32_t Base = A.Size();
			A.V.insert(A.V.end(), G.V.begin(), G.V.end());
			A.N.insert(A.N.end(), G.N.begin(), G.N.end());
			A.C.insert(A.C.end(), G.C.begin(), G.C.end());
			A.UV.insert(A.UV.end(), G.UV.begin(), G.UV.end());
			for (uint32_t K : G.I) A.I.push_back(K + Base);
		}

		// `_quad` : quatre coins dans l'ordre du tour, normale N ; l'ordre est remis à l'endroit pour Godot.
		void WmQuad(FWmArrays& A, const FWmV3 (&P)[4], const FWmV3& N, const FWmColor& C, const FWmUV (&T)[4])
		{
			const uint32_t Base = A.Size();
			for (int K = 0; K < 4; ++K) A.Add(P[K], N, C, T[K]);
			const FWmV3 X = WmCross(P[1] - P[0], P[2] - P[0]);
			if (WmDot(X, N) > 0.f) A.I.insert(A.I.end(), {Base, Base + 2, Base + 1, Base, Base + 3, Base + 2});
			else A.I.insert(A.I.end(), {Base, Base + 1, Base + 2, Base, Base + 2, Base + 3});
		}

		// `_plat` : un rectangle horizontal à la hauteur H, UV = (x, z) du monde.
		void WmFlatQuad(FWmArrays& A, double X0, double X1, double Z0, double Z1, double H, const FWmColor& C)
		{
			const FWmV3 P[4] = {FWmV3::D(X0, H, Z0), FWmV3::D(X1, H, Z0), FWmV3::D(X1, H, Z1), FWmV3::D(X0, H, Z1)};
			const FWmUV T[4] = {{static_cast<float>(X0), static_cast<float>(Z0)}, {static_cast<float>(X1), static_cast<float>(Z0)},
				{static_cast<float>(X1), static_cast<float>(Z1)}, {static_cast<float>(X0), static_cast<float>(Z1)}};
			WmQuad(A, P, FWmV3(0.f, 1.f, 0.f), C, T);
		}

		struct FWmRect
		{
			double X0 = 0.0, X1 = 0.0, Z0 = 0.0, Z1 = 0.0, H = 0.0;
			FWmColor C;
		};

		FWaterFlat WmToFlat(const FWmRect& R)
		{
			FWaterFlat F;
			F.X0 = R.X0;
			F.X1 = R.X1;
			F.Z0 = R.Z0;
			F.Z1 = R.Z1;
			F.H = R.H;
			F.Color[0] = R.C.R;
			F.Color[1] = R.C.G;
			F.Color[2] = R.C.B;
			F.Color[3] = R.C.A;
			return F;
		}

		FWmRect WmFromFlat(const FWaterFlat& F)
		{
			FWmRect R;
			R.X0 = F.X0;
			R.X1 = F.X1;
			R.Z0 = F.Z0;
			R.Z1 = F.Z1;
			R.H = F.H;
			R.C.R = F.Color[0];
			R.C.G = F.Color[1];
			R.C.B = F.Color[2];
			R.C.A = F.Color[3];
			return R;
		}

		bool WmHas(const FCellSet& S, const FCell& C) { return S.count(C) > 0; }

		// `_k` : en vingtièmes, exactement (les coordonnées des plats sont des multiples de 0,05).
		int WmK(double V) { return static_cast<int>(std::round(V * 20.0)); }

		// `_case_plate` : la case C à la hauteur H, avancée de `DEBORD` sous chaque voisine pleine de son étage.
		FWmRect WmCellFlat(const FCell& C, double H, const FCellSet& Cells, const FWmColor& Color)
		{
			const double Xm = WmHas(Cells, C + FCell(-1, 0, 0)) ? Overlap : 0.0;
			const double Xp = WmHas(Cells, C + FCell(1, 0, 0)) ? Overlap : 0.0;
			const double Zm = WmHas(Cells, C + FCell(0, 0, -1)) ? Overlap : 0.0;
			const double Zp = WmHas(Cells, C + FCell(0, 0, 1)) ? Overlap : 0.0;
			FWmRect R;
			R.X0 = C.X - Xm;
			R.X1 = C.X + 1 + Xp;
			R.Z0 = C.Z - Zm;
			R.Z1 = C.Z + 1 + Zp;
			R.H = H;
			R.C = Color;
			return R;
		}

		// `FL.profondeur` : les cases d'eau jusqu'au fond (elle comprise) ; −1 sans fond.
		int WmDepth(const FCellSet& W, const FCellSet& Cells, const FCell& C)
		{
			int N = 0;
			FCell U = C;
			while (WmHas(W, U))
			{
				++N;
				U = U + WmDown;
			}
			return WmHas(Cells, U) ? N : -1;
		}

		// `rectangles_de_nappe` (la surface relue de l'eau, `surface_dessinee` : un greffon n'a pas les tronçons de la mer).
		std::vector<FWmRect> WmSheet(const FCellSet& W, const FCellSet& Cells, int Level, bool bForced, double ForcedH)
		{
			std::vector<FCell> Cases = WaterMesh::DrawnSurface(W, Cells, Level);
			std::sort(Cases.begin(), Cases.end(), [](const FCell& A, const FCell& B)
			{
				return A.Y != B.Y ? A.Y < B.Y : A.Z != B.Z ? A.Z < B.Z : A.X < B.X;
			});
			struct FRow
			{
				int Y = 0, Z = 0, Start = 0, End = 0;
				double Xm = 0.0, Xp = 0.0, Zm = 0.0, Zp = 0.0;
				FWmColor C;
			};
			// 1. Les rangées.
			std::vector<FRow> Rows;
			bool bOpen = false;
			FRow Cur;
			for (const FCell& C : Cases)
			{
				const int P = WmDepth(W, Cells, C);
				const FWmColor Color = WmColorOf(0.0, 0.0, KindStill, P < 0 ? 1.0 : P / 8.0);
				const double Xm = WmHas(Cells, C + FCell(-1, 0, 0)) ? Overlap : 0.0;
				const double Xp = WmHas(Cells, C + FCell(1, 0, 0)) ? Overlap : 0.0;
				const double Zm = WmHas(Cells, C + FCell(0, 0, -1)) ? Overlap : 0.0;
				const double Zp = WmHas(Cells, C + FCell(0, 0, 1)) ? Overlap : 0.0;
				if (bOpen && Cur.Y == C.Y && Cur.Z == C.Z && Cur.End == C.X && Cur.Xp == 0.0 && Xm == 0.0 && Cur.Zm == Zm && Cur.Zp == Zp
					&& Cur.C == Color)
				{
					Cur.End = C.X + 1;
					Cur.Xp = Xp;
					continue;
				}
				if (bOpen) Rows.push_back(Cur);
				Cur = FRow();
				Cur.Y = C.Y;
				Cur.Z = C.Z;
				Cur.Start = C.X;
				Cur.End = C.X + 1;
				Cur.Xm = Xm;
				Cur.Xp = Xp;
				Cur.Zm = Zm;
				Cur.Zp = Zp;
				Cur.C = Color;
				bOpen = true;
			}
			if (bOpen) Rows.push_back(Cur);
			// 2. Les bandes voisines en z, de même étendue.
			using FKey = std::tuple<int, int, double, double, FWmColor>;
			std::vector<FWmRect> Rects;
			std::map<FKey, size_t> Open;
			for (const FRow& B : Rows)
			{
				const double X0 = B.Start - B.Xm;
				const double X1 = B.End + B.Xp;
				const FKey Key(B.Y, B.Z, X0, X1, B.C);
				const auto Found = Open.find(Key);
				size_t K;
				if (Found != Open.end())
				{
					K = Found->second;
					Open.erase(Found);
					Rects[K].Z1 = B.Z + 1 + B.Zp;
				}
				else
				{
					FWmRect R;
					R.X0 = X0;
					R.X1 = X1;
					R.Z0 = B.Z - B.Zm;
					R.Z1 = B.Z + 1 + B.Zp;
					R.H = bForced ? ForcedH : B.Y + Surface;
					R.C = B.C;
					K = Rects.size();
					Rects.push_back(R);
				}
				if (B.Zp == 0.0) Open[FKey(B.Y, B.Z + 1, X0, X1, B.C)] = K;
			}
			return Rects;
		}

		// `_large` : l'océan hors de la boîte, quatre rectangles autour d'elle, sans fond ; sans monde, un seul.
		void WmHorizon(const FWaterBox& B, double H, std::vector<FWmRect>& Out)
		{
			const FWmColor C = WmColorOf(0.0, 0.0, KindStill, 1.0);
			auto R = [&](double X0, double X1, double Z0, double Z1)
			{
				FWmRect Q;
				Q.X0 = X0;
				Q.X1 = X1;
				Q.Z0 = Z0;
				Q.Z1 = Z1;
				Q.H = H;
				Q.C = C;
				Out.push_back(Q);
			};
			if (B.bEmpty)
			{
				R(-Horizon, Horizon, -Horizon, Horizon);
				return;
			}
			const double X0 = B.Lo.X, X1 = B.Hi.X + 1, Z0 = B.Lo.Z, Z1 = B.Hi.Z + 1;
			R(-Horizon, Horizon, -Horizon, Z0);
			R(-Horizon, Horizon, Z1, Horizon);
			R(-Horizon, X0, Z0, Z1);
			R(X1, Horizon, Z0, Z1);
		}

		// `_nappes_du_corps` : la mer (et son large), un lac, les lacs d'une rivière.
		std::vector<FWmRect> WmBodySheets(const FWaterBody& R, const FCellSet& Cells, const FWaterBox& B)
		{
			std::vector<FWmRect> Out;
			if (R.Kind == EWaterKind::Sea)
			{
				// Le monde noyé : les colonnes s'arrêtent au haut de la boîte, pas l'eau.
				const bool bForced = !B.bEmpty && R.Level > B.Hi.Y;
				Out = WmSheet(R.Water, Cells, R.Level, bForced, R.Level + Surface);
				WmHorizon(B, R.Level + Surface, Out);
			}
			else if (R.Kind == EWaterKind::Lake) Out = WmSheet(R.Water, Cells, R.Level, false, 0.0);
			else if (R.Kind == EWaterKind::River)
				for (const FWaterLake& L : R.Lakes)
				{
					const std::vector<FWmRect> S = WmSheet(L.Cells, Cells, L.Level, false, 0.0);
					Out.insert(Out.end(), S.begin(), S.end());
				}
			return Out;
		}

		bool WmIsHorizontal(const FCell& D) { return D.Y == 0 && std::abs(D.X) + std::abs(D.Z) == 1; }

		// `sens_du_cours` : vers la case suivante si elle est à côté, sinon depuis la précédente.
		FCell WmFlowAt(const std::vector<FCourseStep>& Course, size_t I)
		{
			const FCell& C = Course[I].Cell;
			if (I + 1 < Course.size() && WmIsHorizontal(Course[I + 1].Cell - C)) return Course[I + 1].Cell - C;
			if (I > 0 && WmIsHorizontal(C - Course[I - 1].Cell)) return C - Course[I - 1].Cell;
			return FCell(0, 0, 0);
		}

		// Une cascade retenue (`vus[cle]` de l'appli).
		struct FWmFall
		{
			int Axis = 0;
			int Sense = 0;
			double Plane = 0.0;
			int Along = 0;
			double Top = 0.0, Foot = 0.0, Ground = 0.0;
			FCell D;
			bool bStraight = false, bFree0 = false, bFree1 = false;
			double U0 = 0.0, U1 = 0.0;
		};

		// Ce que les rivières d'une couche partagent : les cases déjà couvertes d'une bande, les cascades par clé (dans
		// l'ordre où elles ont été retenues), les eaux dormantes.
		struct FWmSeen
		{
			FCellSet Bands;
			std::map<std::tuple<int, int, int>, size_t> FallKeys;
			std::vector<FWmFall> Falls;
			std::vector<const FCellSet*> Dormant;
		};

		// `_lame` : la cascade de LIP à BOTTOM, sur le plan de la falaise qu'elle quitte (le côté −D).
		void WmFall(const FCell& Lip, const FCell& Bottom, const FCell& D, const FCellSet& Cells, FWmSeen& Seen)
		{
			const double Top = Lip.Y + River;
			double Foot = Bottom.Y - 0.3;
			double Ground = WmHas(Cells, Bottom + WmDown) ? Bottom.Y + River : Foot;
			// Tombée dans une eau dormante, le remous est sur SA nappe.
			for (const FCellSet* W : Seen.Dormant)
				if (WmHas(*W, Bottom))
				{
					FCell H = Bottom;
					while (WmHas(*W, H + WmUp)) H = H + WmUp;
					Ground = H.Y + Surface;
					Foot = std::min(Foot, Ground - 0.15);
					break;
				}
			int Axis = D.X != 0 ? 0 : 2;
			int Sense = D.X != 0 ? D.X : D.Z;
			int Along = Axis == 0 ? Lip.Z : Lip.X;
			double Plane = 0.0;
			if (Sense == 0)
			{
				Axis = 2;
				Sense = 1;
				Along = Lip.X;
				Plane = Lip.Z + 0.5;
			}
			else
			{
				const int Edge = Axis == 0 ? Lip.X : Lip.Z;
				Plane = Sense > 0 ? static_cast<double>(Edge) : static_cast<double>(Edge + 1);
			}
			const std::tuple<int, int, int> Key(Axis, WmK(Plane), Along);
			const auto Found = Seen.FallKeys.find(Key);
			if (Found == Seen.FallKeys.end())
			{
				FWmFall L;
				L.Axis = Axis;
				L.Sense = Sense;
				L.Plane = Plane;
				L.Along = Along;
				L.Top = Top;
				L.Foot = Foot;
				L.Ground = Ground;
				L.D = D;
				Seen.FallKeys[Key] = Seen.Falls.size();
				Seen.Falls.push_back(L);
			}
			else
			{
				FWmFall& L = Seen.Falls[Found->second];
				L.Top = std::max(L.Top, Top);
				L.Foot = std::min(L.Foot, Foot);
				L.Ground = std::min(L.Ground, Ground);
			}
		}

		// `_riviere` : une bande par case du cours qui repose sur la matière, une cascade par suite de chutes, la source.
		void WmRiver(const std::vector<FCourseStep>& Course, const FCellSet& Cells, std::vector<FWmRect>& Flats, FWmSeen& Seen,
			std::vector<FCell>& Springs)
		{
			const size_t N = Course.size();
			if (N > 0 && Course[0].Kind == ECourseKind::Flow && WmHas(Cells, Course[0].Cell + WmDown)
				&& std::find(Springs.begin(), Springs.end(), Course[0].Cell) == Springs.end())
				Springs.push_back(Course[0].Cell);
			for (size_t I = 0; I < N; ++I)
			{
				const FCourseStep& E = Course[I];
				const FCell& C = E.Cell;
				if (E.Kind == ECourseKind::Lake || !WmHas(Cells, C + WmDown) || WmHas(Seen.Bands, C)) continue;
				const FCell D = WmFlowAt(Course, I);
				Seen.Bands.insert(C);
				Flats.push_back(WmCellFlat(C, C.Y + River, Cells, WmColorOf(D.X, D.Z, KindRiver, 0.05)));
			}
			size_t I = 0;
			while (I < N)
			{
				const FCell C = Course[I].Cell;
				if (Course[I].Kind == ECourseKind::Fall)
				{
					size_t J = I;
					while (J < N && Course[J].Kind == ECourseKind::Fall) ++J;
					const FCell Lip = I > 0 ? Course[I - 1].Cell : C + WmUp;
					FCell D(0, 0, 0);
					if (I >= 2 && WmIsHorizontal(Lip - Course[I - 2].Cell)) D = Lip - Course[I - 2].Cell;
					else
						for (const FCell& F : WmHorizontal)
							if (WmHas(Cells, C - F))
							{
								D = F;
								break;
							}
					WmFall(Lip, Course[J - 1].Cell, D, Cells, Seen);
					I = J;
				}
				else ++I;
			}
		}

		// `_chutes` : la courbe (fine en haut), puis tous les 0,5, puis le pied — un PackedFloat32Array.
		std::vector<float> WmDrops(double Total)
		{
			std::vector<float> C;
			for (double H : {0.0, 0.02, 0.06, 0.12, 0.2, 0.3, 0.42, 0.55, Arc})
				if (H < Total - 0.01) C.push_back(static_cast<float>(H));
			double H = Arc + 0.5;
			while (H < Total - 0.2)
			{
				C.push_back(static_cast<float>(H));
				H += 0.5;
			}
			C.push_back(static_cast<float>(Total));
			return C;
		}

		double WmOut(double Drop)
		{
			return Sheet * std::sqrt(WmClamp(Drop / Arc, 0.0, 1.0)) + std::min(Flare * std::max(Drop - Arc, 0.0), FlareMax);
		}

		double WmProfile(double U, double U0, double U1, bool bFree0, bool bFree1)
		{
			double R = 1.0;
			if (bFree0 && U < U0 + Rounding)
			{
				const double T = WmClamp((U - U0) / Rounding, 0.0, 1.0);
				R = std::min(R, std::sqrt(1.0 - (1.0 - T) * (1.0 - T)));
			}
			if (bFree1 && U > U1 - Rounding)
			{
				const double T = WmClamp((U1 - U) / Rounding, 0.0, 1.0);
				R = std::min(R, std::sqrt(1.0 - (1.0 - T) * (1.0 - T)));
			}
			return R;
		}

		double WmFront(double R, double Drop)
		{
			const double A = -IntoRock * WmClamp(Drop / 0.15, 0.0, 1.0);
			return A + (WmOut(Drop) - A) * R;
		}

		// `_point_de_lame`
		FWmV3 WmFallPoint(const FWmFall& L, double U, double Drop)
		{
			const double R = L.bStraight ? 0.0 : WmProfile(U, L.U0, L.U1, L.bFree0, L.bFree1);
			const double P = L.Plane + (L.bStraight ? 0.0 : WmFront(R, Drop)) * L.Sense;
			const double Y = L.Top - Drop;
			return L.Axis == 0 ? FWmV3::D(P, Y, U) : FWmV3::D(U, Y, P);
		}

		FWmV3 WmSenseVector(const FWmFall& L)
		{
			return L.Axis == 0 ? FWmV3(static_cast<float>(L.Sense), 0.f, 0.f) : FWmV3(0.f, 0.f, static_cast<float>(L.Sense));
		}

		// `_normale_de_lame` : par différences, vers l'AVANT.
		FWmV3 WmFallNormal(const FWmFall& L, double U, double Drop)
		{
			const double E = 0.01;
			const FWmV3 Tu = WmFallPoint(L, U + E, Drop) - WmFallPoint(L, U - E, Drop);
			const FWmV3 Th = WmFallPoint(L, U, Drop + E) - WmFallPoint(L, U, std::max(Drop - E, 0.0));
			const int Sign = L.Axis == 0 ? -L.Sense : L.Sense;
			const FWmV3 N = WmCross(Th, Tu) * static_cast<float>(Sign);
			if (WmLength(N) < 1e-9f) return WmSenseVector(L);
			return WmNormalized(N);
		}

		// `_travers` : les bouts arrondis finement, les frontières des cases, le milieu.
		std::vector<double> WmAcross(const FWmFall& L)
		{
			std::vector<double> Us;
			for (double F : {0.0, 0.05, 0.1, 0.2, 0.3, Rounding})
			{
				if (L.bFree0) Us.push_back(L.U0 + F);
				if (L.bFree1) Us.push_back(L.U1 - F);
			}
			for (double U : {static_cast<double>(L.Along), L.Along + 0.5, L.Along + 1.0}) Us.push_back(U);
			std::sort(Us.begin(), Us.end());
			std::vector<double> Kept;
			for (double U : Us)
			{
				if (U < L.U0 - 0.001 || U > L.U1 + 0.001) continue;
				if (Kept.empty() || U - Kept.back() > 0.005) Kept.push_back(U);
			}
			return Kept;
		}

		// `_couronne` : rangée K à Offsets[K] du pied, Rises[K] au-dessus de l'eau, d'écume Foams[K] (× Weights[I]).
		FWmGrid WmCrown(const std::vector<FWmV3>& Feet, const std::vector<FWmV3>& Dirs, const std::vector<double>& Us, double FlowX,
			double FlowZ, double Ground, const double (&Offsets)[4], const double (&Rises)[4], const double (&Foams)[4], bool bFlat,
			const std::vector<double>* Weights)
		{
			FWmGrid G;
			for (int K = 0; K < 4; ++K)
			{
				std::vector<FWmV3> Rp, Rn;
				std::vector<FWmColor> Rc;
				std::vector<FWmUV> Ruv;
				for (size_t I = 0; I < Us.size(); ++I)
				{
					const FWmV3 P = Feet[I] + Dirs[I] * static_cast<float>(Offsets[K])
						+ FWmV3(0.f, static_cast<float>(Rises[K] + (bFlat ? 0.02 : 0.0)), 0.f);
					Rp.push_back(P);
					Rn.push_back(bFlat ? FWmV3(0.f, 1.f, 0.f) : Dirs[I]);
					Rc.push_back(WmColorOf(FlowX, FlowZ, KindFoam, Foams[K] * (Weights ? (*Weights)[I] : 1.0)));
					Ruv.push_back({static_cast<float>(Us[I]), bFlat ? static_cast<float>(Ground - Offsets[K] * 1.5) : P.Y});
				}
				G.P.push_back(Rp);
				G.N.push_back(Rn);
				G.C.push_back(Rc);
				G.UV.push_back(Ruv);
			}
			return G;
		}

		// `_lame_calculee` : sa nappe compilée, la rangée du haut (des points de jonction), son anneau, ses embruns.
		struct FWmFallDrawn
		{
			FWmArrays Sheet;
			std::vector<FWmV3> TopRow;
			FWmArrays Ring, Spray;
		};

		FWmFallDrawn WmFallDrawn(FWmFall& L)
		{
			L.U0 = L.Along - (L.bFree0 ? Overhang : 0.0);
			L.U1 = L.Along + 1.0 + (L.bFree1 ? Overhang : 0.0);
			const std::vector<double> Us = WmAcross(L);
			const double Total = L.Top - L.Foot;
			const double Fx = L.D.X, Fz = L.D.Z;
			FWmGrid G;
			for (float DropF : WmDrops(Total))
			{
				const double Drop = DropF;
				std::vector<FWmV3> Rp, Rn;
				std::vector<FWmColor> Rc;
				std::vector<FWmUV> Ruv;
				for (double U : Us)
				{
					const FWmV3 P = WmFallPoint(L, U, Drop);
					const double E = WmClamp(1.0 - (static_cast<double>(P.Y) - L.Ground) / FoamRise, 0.0, 1.0);
					Rp.push_back(P);
					Rn.push_back(WmFallNormal(L, U, Drop));
					Rc.push_back(WmColorOf(Fx, Fz, KindFall, E * E));
					Ruv.push_back({static_cast<float>(U), P.Y});
				}
				G.P.push_back(Rp);
				G.N.push_back(Rn);
				G.C.push_back(Rc);
				G.UV.push_back(Ruv);
			}
			// LE REMOUS : au pied, là où la nappe traverse l'eau ; chaque point s'écarte selon la normale de la nappe.
			const double GroundDrop = WmClamp(L.Top - L.Ground, 0.0, Total);
			std::vector<FWmV3> Feet, Dirs;
			for (double U : Us)
			{
				const FWmV3 P = WmFallPoint(L, U, GroundDrop);
				const FWmV3 N = WmFallNormal(L, U, GroundDrop);
				FWmV3 H(N.X, 0.f, N.Z);
				if (WmLength(H) < 0.2f) H = WmSenseVector(L);
				Feet.push_back(FWmV3(P.X, static_cast<float>(L.Ground), P.Z));
				Dirs.push_back(WmNormalized(H));
			}
			static const double RingOffsets[4] = {0.0, 0.25, 0.55, Churn};
			static const double RingRises[4] = {0.0, 0.0, 0.0, 0.0};
			static const double RingFoams[4] = {1.0, 0.85, 0.45, 0.0};
			static const double SprayOffsets[4] = {0.06, 0.16, 0.22, 0.2};
			static const double SprayRises[4] = {0.0, 0.3, 0.6, Spray};
			static const double SprayFoams[4] = {0.95, 0.7, 0.35, 0.0};
			const FWmGrid Ring = WmCrown(Feet, Dirs, Us, Fx, Fz, L.Ground, RingOffsets, RingRises, RingFoams, true, nullptr);
			// Les embruns montent DEVANT la nappe seulement : sur les bouts arrondis, leur écume × le profil³.
			std::vector<double> Weights;
			for (double U : Us) Weights.push_back(L.bStraight ? 1.0 : std::pow(WmProfile(U, L.U0, L.U1, L.bFree0, L.bFree1), 3.0));
			const FWmGrid SprayGrid = WmCrown(Feet, Dirs, Us, Fx, Fz, L.Ground, SprayOffsets, SprayRises, SprayFoams, false, &Weights);
			FWmFallDrawn Out;
			Out.Sheet = WmCompile(G);
			Out.TopRow = G.P.empty() ? std::vector<FWmV3>() : G.P[0];
			Out.Ring = WmCompile(Ring);
			Out.Spray = WmCompile(SprayGrid);
			return Out;
		}

		// `_source` : le bouillon en disque, bombé au centre, et son petit voile d'embruns.
		void WmSpring(const FCell& C, std::vector<FWmArrays>& Foam)
		{
			const FWmV3 Centre = FWmV3::D(C.X + 0.5, C.Y + River, C.Z + 0.5);
			const int Turns = 16;
			const double Radii[4] = {0.0, 0.2, 0.42, Spring};
			const double Domes[4] = {SpringDome, SpringDome * 0.7, SpringDome * 0.3, 0.02};
			const double Foams[4] = {1.0, 0.95, 0.6, 0.0};
			FWmGrid Disc;
			for (int K = 0; K < 4; ++K)
			{
				std::vector<FWmV3> Rp, Rn;
				std::vector<FWmColor> Rc;
				std::vector<FWmUV> Ruv;
				for (int I = 0; I < Turns + 1; ++I)
				{
					const double Ang = WmTau * static_cast<double>(I % Turns) / Turns;
					const FWmV3 D = FWmV3::D(std::cos(Ang), 0.0, std::sin(Ang));
					Rp.push_back(Centre + D * static_cast<float>(Radii[K]) + FWmV3(0.f, static_cast<float>(Domes[K]), 0.f));
					Rn.push_back(FWmV3(0.f, 1.f, 0.f));
					Rc.push_back(WmColorOf(0.0, 0.0, KindFoam, Foams[K]));
					Ruv.push_back({static_cast<float>(Ang * 0.6), static_cast<float>(Centre.Y - Radii[K] * 1.5)});
				}
				Disc.P.push_back(Rp);
				Disc.N.push_back(Rn);
				Disc.C.push_back(Rc);
				Disc.UV.push_back(Ruv);
			}
			const double VeilRadii[3] = {0.12, 0.2, 0.24};
			const double VeilLifts[3] = {0.02, 0.18, 0.34};
			const double VeilFoams[3] = {0.8, 0.45, 0.0};
			FWmGrid Veil;
			for (int K = 0; K < 3; ++K)
			{
				std::vector<FWmV3> Rp, Rn;
				std::vector<FWmColor> Rc;
				std::vector<FWmUV> Ruv;
				for (int I = 0; I < Turns + 1; ++I)
				{
					const double Ang = WmTau * static_cast<double>(I % Turns) / Turns;
					const FWmV3 D = FWmV3::D(std::cos(Ang), 0.0, std::sin(Ang));
					Rp.push_back(Centre + D * static_cast<float>(VeilRadii[K]) + FWmV3(0.f, static_cast<float>(VeilLifts[K]), 0.f));
					Rn.push_back(D);
					Rc.push_back(WmColorOf(0.0, 0.0, KindFoam, VeilFoams[K]));
					Ruv.push_back({static_cast<float>(Ang * 0.6), static_cast<float>(Centre.Y + VeilLifts[K])});
				}
				Veil.P.push_back(Rp);
				Veil.N.push_back(Rn);
				Veil.C.push_back(Rc);
				Veil.UV.push_back(Ruv);
			}
			Foam.push_back(WmCompile(Disc));
			Foam.push_back(WmCompile(Veil));
		}

		// Les valeurs triées de L strictement entre A et B.
		void WmBetween(const std::vector<int>* L, int A, int B, std::vector<int>& Out)
		{
			Out.clear();
			if (!L) return;
			for (auto It = std::upper_bound(L->begin(), L->end(), A); It != L->end() && *It < B; ++It) Out.push_back(*It);
		}

		// `_poser_les_plats` : chaque rectangle reçoit les sommets des autres (et des hauts de cascade) posés sur ses côtés,
		// et se dessine alors en éventail autour de son centre ; sans sommet inséré, deux triangles.
		void WmPoseFlats(FWmArrays& A, const std::vector<FWmRect>& Flats, const std::vector<FWmV3>& Points)
		{
			std::map<std::pair<int, int>, std::vector<int>> OnZ, OnX;   // (h, z) → x ; (h, x) → z
			for (const FWmV3& Q : Points)
			{
				OnZ[{WmK(Q.Y), WmK(Q.Z)}].push_back(WmK(Q.X));
				OnX[{WmK(Q.Y), WmK(Q.X)}].push_back(WmK(Q.Z));
			}
			for (const FWmRect& R : Flats)
			{
				const int Hk = WmK(R.H);
				for (double X : {R.X0, R.X1})
					for (double Z : {R.Z0, R.Z1})
					{
						OnZ[{Hk, WmK(Z)}].push_back(WmK(X));
						OnX[{Hk, WmK(X)}].push_back(WmK(Z));
					}
			}
			for (auto* M : {&OnZ, &OnX})
				for (auto& Entry : *M)
				{
					std::sort(Entry.second.begin(), Entry.second.end());
					Entry.second.erase(std::unique(Entry.second.begin(), Entry.second.end()), Entry.second.end());
				}
			auto Line = [](const std::map<std::pair<int, int>, std::vector<int>>& M, int H, int K) -> const std::vector<int>*
			{
				const auto Found = M.find({H, K});
				return Found == M.end() ? nullptr : &Found->second;
			};
			std::vector<std::pair<int, int>> Tour;
			std::vector<int> Mid;
			for (const FWmRect& R : Flats)
			{
				const int Hk = WmK(R.H), X0 = WmK(R.X0), X1 = WmK(R.X1), Z0 = WmK(R.Z0), Z1 = WmK(R.Z1);
				// Le tour, dans un sens fixe : (x0,z0) → (x1,z0) → (x1,z1) → (x0,z1).
				Tour.clear();
				Tour.push_back({X0, Z0});
				WmBetween(Line(OnZ, Hk, Z0), X0, X1, Mid);
				for (int X : Mid) Tour.push_back({X, Z0});
				Tour.push_back({X1, Z0});
				WmBetween(Line(OnX, Hk, X1), Z0, Z1, Mid);
				for (int Z : Mid) Tour.push_back({X1, Z});
				Tour.push_back({X1, Z1});
				WmBetween(Line(OnZ, Hk, Z1), X0, X1, Mid);
				for (auto It = Mid.rbegin(); It != Mid.rend(); ++It) Tour.push_back({*It, Z1});
				Tour.push_back({X0, Z1});
				WmBetween(Line(OnX, Hk, X0), Z0, Z1, Mid);
				for (auto It = Mid.rbegin(); It != Mid.rend(); ++It) Tour.push_back({X0, *It});
				if (Tour.size() == 4)
				{
					WmFlatQuad(A, R.X0, R.X1, R.Z0, R.Z1, R.H, R.C);
					continue;
				}
				const uint32_t Base = A.Size();
				const FWmV3 Centre = FWmV3::D((R.X0 + R.X1) * 0.5, R.H, (R.Z0 + R.Z1) * 0.5);
				const FWmV3 Up(0.f, 1.f, 0.f);
				A.Add(Centre, Up, R.C, {Centre.X, Centre.Z});
				for (const auto& T : Tour)
				{
					const FWmV3 P = FWmV3::D(T.first / 20.0, R.H, T.second / 20.0);
					A.Add(P, Up, R.C, {P.X, P.Z});
				}
				const uint32_t N = static_cast<uint32_t>(Tour.size());
				// Le produit vectoriel de (centre, k, k+1) pointe vers le BAS : l'ordre que Godot veut.
				for (uint32_t K = 0; K < N; ++K) A.I.insert(A.I.end(), {Base, Base + 1 + K, Base + 1 + (K + 1) % N});
			}
		}
	}

	namespace WaterMesh
	{
		std::vector<FCell> DrawnSurface(const FCellSet& W, const FCellSet& Cells, int Level)
		{
			std::vector<FCell> S;
			for (const FCell& C : W)
			{
				const FCell H = C + WmUp;
				if (!WmHas(W, H) && !WmHas(Cells, H)) S.push_back(C);
			}
			for (const FCell& C : W)
				if (C.Y == Level && WmHas(Cells, C + WmUp)) S.push_back(C);
			return S;
		}

		FWaterMesh Build(const std::vector<const FWaterBody*>& Bodies, const FCellSet& Cells, const FWaterBox& Box, FWaterMeshMemory* Memory)
		{
			FWmArrays A;
			std::vector<FWmRect> Flats;
			FWmSeen Seen;
			std::vector<FCell> Springs;
			// Les eaux DORMANTES (mer, lacs, lacs des rivières) : une cascade qui y tombe pose son remous sur leur nappe.
			for (const FWaterBody* R : Bodies)
			{
				if (!R || !R->Error.empty()) continue;
				if (R->Kind == EWaterKind::Sea || R->Kind == EWaterKind::Lake) Seen.Dormant.push_back(&R->Water);
				else if (R->Kind == EWaterKind::River)
					for (const FWaterLake& L : R->Lakes) Seen.Dormant.push_back(&L.Cells);
			}
			if (Memory)
			{
				Memory->Reused = 0;
				Memory->Sheets.resize(Bodies.size());
			}
			for (size_t J = 0; J < Bodies.size(); ++J)
			{
				const FWaterBody* R = Bodies[J];
				if (!R || !R->Error.empty())
				{
					if (Memory) Memory->Sheets[J] = {0, {}};
					continue;
				}
				// La mémoire des nappes : un corps repris (même Id) a les mêmes rectangles.
				if (Memory && R->Id != 0 && Memory->Sheets[J].first == R->Id)
				{
					for (const FWaterFlat& F : Memory->Sheets[J].second) Flats.push_back(WmFromFlat(F));
					++Memory->Reused;
				}
				else
				{
					const std::vector<FWmRect> Sheets = WmBodySheets(*R, Cells, Box);
					Flats.insert(Flats.end(), Sheets.begin(), Sheets.end());
					if (Memory)
					{
						std::vector<FWaterFlat> Kept;
						for (const FWmRect& S : Sheets) Kept.push_back(WmToFlat(S));
						Memory->Sheets[J] = {R->Id, std::move(Kept)};
					}
				}
				if (R->Kind == EWaterKind::River) WmRiver(R->Course, Cells, Flats, Seen, Springs);
			}
			// Les cascades (opaques) tout de suite ; leur remous, transparent, en dernier.
			std::vector<FWmV3> Points;
			std::vector<FWmArrays> Foam;
			for (FWmFall& L : Seen.Falls)
			{
				L.bStraight = L.D.IsZero();
				const int Pk = WmK(L.Plane);
				L.bFree0 = !L.bStraight && !Seen.FallKeys.count(std::make_tuple(L.Axis, Pk, L.Along - 1));
				L.bFree1 = !L.bStraight && !Seen.FallKeys.count(std::make_tuple(L.Axis, Pk, L.Along + 1));
				FWmFallDrawn Drawn = WmFallDrawn(L);
				WmPose(A, Drawn.Sheet);
				// SON HAUT EST SUR LE BOUT DE LA BANDE : ses sommets y sont insérés (pas de jonction en T).
				Points.insert(Points.end(), Drawn.TopRow.begin(), Drawn.TopRow.end());
				Foam.push_back(std::move(Drawn.Ring));
				Foam.push_back(std::move(Drawn.Spray));
			}
			for (const FCell& C : Springs) WmSpring(C, Foam);
			WmPoseFlats(A, Flats, Points);
			for (const FWmArrays& G : Foam) WmPose(A, G);
			// Les tableaux de Godot (triangles horaires) → le format (anti-horaires) : chaque triangle retourné.
			FWaterMesh Out;
			Out.Vertices.resize(A.V.size());
			for (size_t K = 0; K < A.V.size(); ++K)
			{
				FWaterVertex& V = Out.Vertices[K];
				V.Position[0] = A.V[K].X;
				V.Position[1] = A.V[K].Y;
				V.Position[2] = A.V[K].Z;
				V.Normal[0] = A.N[K].X;
				V.Normal[1] = A.N[K].Y;
				V.Normal[2] = A.N[K].Z;
				V.Color[0] = A.C[K].R;
				V.Color[1] = A.C[K].G;
				V.Color[2] = A.C[K].B;
				V.Color[3] = A.C[K].A;
				V.UV[0] = A.UV[K].U;
				V.UV[1] = A.UV[K].V;
			}
			Out.Indices.resize(A.I.size());
			for (size_t K = 0; K + 2 < A.I.size(); K += 3)
			{
				Out.Indices[K] = A.I[K];
				Out.Indices[K + 1] = A.I[K + 2];
				Out.Indices[K + 2] = A.I[K + 1];
			}
			return Out;
		}

		FWaterMesh Build(const std::vector<FWaterBody>& Bodies, const FCellSet& Cells)
		{
			std::vector<const FWaterBody*> Pointers;
			for (const FWaterBody& B : Bodies) Pointers.push_back(&B);
			return Build(Pointers, Cells, Water::BoxOf(Cells), nullptr);
		}
	}
}
