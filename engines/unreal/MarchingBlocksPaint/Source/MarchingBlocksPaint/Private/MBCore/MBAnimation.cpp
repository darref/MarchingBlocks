// MarchingBlocks Paint for Unreal — les textures animées (voir MBAnimation.h). Réécrites depuis la règle du cœur
// (`animation_materiau.gd` : `depuis_format`, `normaliser`, `image_au_temps`, `pulsation_au_temps`,
// `defilement_au_temps`, `phase_de`) ; éprouvées par Tests/animation_conformance.json.
//
// ⚠ Préfixe Anm… (les « unity builds » d'Unreal fusionnent les .cpp).

#include "MBCore/MBAnimation.h"

#include <algorithm>
#include <cmath>

namespace MBPaint
{
	namespace
	{
		const char* const AnmChannelNames[4] = {"albedo", "normal", "orm", "emission"};

		double AnmClamp(double X, double Lo, double Hi) { return std::max(Lo, std::min(Hi, X)); }

		// Un nombre (entier ou réel) — sinon le défaut : une valeur du mauvais type est ignorée.
		double AnmNumber(const FJsonValue& Track, const char* Key, double Default)
		{
			const FJsonValue* X = Track.Find(Key);
			return X && X->IsNumber() ? X->AsReal() : Default;
		}

		bool AnmBool(const FJsonValue& Track, const char* Key, bool Default)
		{
			const FJsonValue* X = Track.Find(Key);
			return X && X->Type == FJsonValue::EType::Bool ? X->Bool : Default;
		}

		double AnmFract(double X) { return X - std::floor(X); }

		int AnmPosMod(long long K, long long N)
		{
			const long long M = K % N;
			return static_cast<int>(M < 0 ? M + N : M);
		}
	}

	namespace Animation
	{
		const char* ChannelName(EAnimChannel Channel) { return AnmChannelNames[static_cast<int>(Channel)]; }

		FAnimation Read(const FJsonValue& Value)
		{
			FAnimation A;
			if (Value.Type != FJsonValue::EType::Object) return A;
			const FJsonValue& Fmt = Value["format"];
			if (Fmt.Type != FJsonValue::EType::String || Fmt.String != Format) return A;
			const FJsonValue& Version = Value["version"];
			if (!Version.IsWhole() || Version.AsReal() < 1.0 || Version.AsReal() > static_cast<double>(SupportedVersion)) return A;
			for (int Ch = 0; Ch < 4; ++Ch)
			{
				const FJsonValue& C = Value[AnmChannelNames[Ch]];
				if (C.Type != FJsonValue::EType::Object) continue;
				FAnimChannelTracks& T = A.Channels[Ch];
				const FJsonValue& S = C["scroll"];
				if (S.Type == FJsonValue::EType::Object)
				{
					T.Scroll.bPresent = true;
					T.Scroll.U = AnmClamp(AnmNumber(S, "u", 0.0), -ScrollMax, ScrollMax);
					T.Scroll.V = AnmClamp(AnmNumber(S, "v", -0.25), -ScrollMax, ScrollMax);
					T.Scroll.bSynced = AnmBool(S, "synced", true);
				}
				const FJsonValue& F = C["frames"];
				if (F.Type == FJsonValue::EType::Object)
				{
					const FJsonValue& Images = F["images"];
					if (Images.Type == FJsonValue::EType::Array)
						for (const FJsonValue& P : Images.Array)
							if (P.Type == FJsonValue::EType::String && !P.String.empty() && T.Frames.Images.size() < static_cast<size_t>(FramesMax))
								T.Frames.Images.push_back(P.String);
					// Une piste d'images sans image n'existe pas.
					T.Frames.bPresent = !T.Frames.Images.empty();
					T.Frames.Fps = AnmClamp(AnmNumber(F, "fps", 12.0), 0.1, FpsMax);
					T.Frames.bPingPong = AnmBool(F, "ping_pong", false);
					T.Frames.bSynced = AnmBool(F, "synced", false);
				}
				// La pulsation est celle de l'émission seule.
				const FJsonValue& P = C["pulse"];
				if (P.Type == FJsonValue::EType::Object && Ch == static_cast<int>(EAnimChannel::Emission))
				{
					T.Pulse.bPresent = true;
					T.Pulse.Frequency = AnmClamp(AnmNumber(P, "frequency", 0.5), 0.0, 20.0);
					T.Pulse.Minimum = AnmClamp(AnmNumber(P, "minimum", 0.2), 0.0, 1.0);
					T.Pulse.bSynced = AnmBool(P, "synced", false);
				}
			}
			return A;
		}

		FJsonValue ToJson(const FAnimation& A)
		{
			FJsonValue Out = FJsonValue::MakeObject();
			if (A.IsEmpty()) return Out;
			Out.Set("format", FJsonValue::MakeString(Format));
			Out.Set("version", FJsonValue::MakeInt(SupportedVersion));
			for (int Ch = 0; Ch < 4; ++Ch)
			{
				const FAnimChannelTracks& T = A.Channels[Ch];
				if (T.IsEmpty()) continue;
				FJsonValue C = FJsonValue::MakeObject();
				if (T.Scroll.bPresent)
				{
					FJsonValue S = FJsonValue::MakeObject();
					S.Set("u", FJsonValue::MakeReal(T.Scroll.U)).Set("v", FJsonValue::MakeReal(T.Scroll.V))
						.Set("synced", FJsonValue::MakeBool(T.Scroll.bSynced));
					C.Set("scroll", S);
				}
				if (T.Frames.bPresent)
				{
					FJsonValue F = FJsonValue::MakeObject();
					FJsonValue Images = FJsonValue::MakeArray();
					for (const std::string& I : T.Frames.Images) Images.Push(FJsonValue::MakeString(I));
					F.Set("images", Images).Set("fps", FJsonValue::MakeReal(T.Frames.Fps))
						.Set("ping_pong", FJsonValue::MakeBool(T.Frames.bPingPong)).Set("synced", FJsonValue::MakeBool(T.Frames.bSynced));
					C.Set("frames", F);
				}
				if (T.Pulse.bPresent)
				{
					FJsonValue P = FJsonValue::MakeObject();
					P.Set("frequency", FJsonValue::MakeReal(T.Pulse.Frequency)).Set("minimum", FJsonValue::MakeReal(T.Pulse.Minimum))
						.Set("synced", FJsonValue::MakeBool(T.Pulse.bSynced));
					C.Set("pulse", P);
				}
				Out.Set(AnmChannelNames[Ch], C);
			}
			return Out;
		}

		int FrameAt(int Count, double Fps, bool bPingPong, double T, double Phase)
		{
			if (Count <= 0) return 0;
			const long long K = static_cast<long long>(std::floor(T * Fps + Phase * static_cast<double>(Count)));
			if (bPingPong && Count > 1)
			{
				const long long P = 2LL * Count - 2;
				const int M = AnmPosMod(K, P);
				return M < Count ? M : static_cast<int>(P - M);
			}
			return AnmPosMod(K, Count);
		}

		double PulseAt(double Frequency, double Minimum, double T, double Phase)
		{
			if (Frequency <= 0.0) return 1.0;
			const double TwoPi = 6.283185307179586;
			return Minimum + (1.0 - Minimum) * (0.5 + 0.5 * std::cos(TwoPi * (T * Frequency + Phase)));
		}

		void ScrollAt(double U, double V, double T, bool bSynced, double Phase, double& OutU, double& OutV)
		{
			const double K = T + (bSynced ? 0.0 : 7.0 * Phase);
			OutU = U * K;
			OutV = V * K;
		}

		double PhaseOf(double Ox, double Oy, double Oz)
		{
			const double P[3] = {std::floor(Ox + 0.5), std::floor(Oy + 0.5), std::floor(Oz + 0.5)};
			const double Add[3] = {0.71, 0.113, 0.419};
			double Q[3];
			for (int I = 0; I < 3; ++I) Q[I] = AnmFract(P[I] * 0.3183099 + Add[I]) * 17.0;
			return AnmFract(Q[0] * Q[1] * Q[2] * (Q[0] + Q[1] + Q[2]));
		}

		bool ReadGlbJson(const std::vector<uint8_t>& Bytes, FJsonValue& Out, std::string& Error)
		{
			auto U32 = [&Bytes](size_t At)
			{
				return static_cast<uint32_t>(Bytes[At]) | (static_cast<uint32_t>(Bytes[At + 1]) << 8)
					| (static_cast<uint32_t>(Bytes[At + 2]) << 16) | (static_cast<uint32_t>(Bytes[At + 3]) << 24);
			};
			if (Bytes.size() < 20 || U32(0) != 0x46546C67u) { Error = "not a glTF binary (.glb)"; return false; }
			const size_t Length = U32(12);
			if (U32(16) != 0x4E4F534Au || 20 + Length > Bytes.size()) { Error = "the first chunk of the .glb is not its JSON"; return false; }
			const std::string Text(reinterpret_cast<const char*>(Bytes.data()) + 20, Length);
			return ParseJson(Text, Out, Error);
		}

		std::map<std::string, FAnimation> ByMaterial(const FJsonValue& Gltf)
		{
			std::map<std::string, FAnimation> Out;
			for (const FJsonValue& M : Gltf["materials"].Array)
			{
				const FAnimation A = Read(M["extras"]["mb_animation"]);
				const std::string& Name = M["name"].String;
				if (!A.IsEmpty() && !Out.count(Name)) Out[Name] = A;
			}
			return Out;
		}
	}
}
