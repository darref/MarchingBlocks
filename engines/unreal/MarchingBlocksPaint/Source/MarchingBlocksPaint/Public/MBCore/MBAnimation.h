// MarchingBlocks Paint for Unreal — ANIMATED TEXTURES: the extras.mb_animation of a tiles.glb material, and the rule
// of time (which frame, how much pulse, which scroll, which phase).
//
// Standard C++, no Unreal dependency: Tests/animation_conformance.json (computed by the MarchingBlocks tool itself)
// proves it; its rules_text says the rule in full. The material of tiles.glb shows frame 0 by itself: ignoring the
// animation still shows the tile right.
//
// ⚠ Unreal's glTF importer (Interchange) does not reliably expose material extras: the plugin reads the JSON chunk
// of tiles.glb itself (ReadGlbJson) and matches materials by NAME (several materials of the file may carry the same
// name: they are copies of the same, with the same animation).

#pragma once

#include "MBCore/MBJson.h"
#include "MBCore/MBRule.h"

#include <cstdint>
#include <map>
#include <string>
#include <vector>

#ifndef MARCHINGBLOCKSPAINT_API
#define MARCHINGBLOCKSPAINT_API
#endif

namespace MBPaint
{
	/// The channels, in the format's order.
	enum class EAnimChannel { Albedo, Normal, Orm, Emission };

	struct FAnimScroll
	{
		bool bPresent = false;
		double U = 0.0;
		double V = -0.25;
		bool bSynced = true;
	};

	struct FAnimFrames
	{
		bool bPresent = false;
		/// Paths RELATIVE to the .mbset folder, in order (1 to 256).
		std::vector<std::string> Images;
		double Fps = 12.0;
		bool bPingPong = false;
		bool bSynced = false;
	};

	struct FAnimPulse
	{
		bool bPresent = false;
		double Frequency = 0.5;
		double Minimum = 0.2;
		bool bSynced = false;
	};

	struct FAnimChannelTracks
	{
		FAnimScroll Scroll;
		FAnimFrames Frames;
		/// The emission only.
		FAnimPulse Pulse;
		bool IsEmpty() const { return !Scroll.bPresent && !Frames.bPresent && !Pulse.bPresent; }
	};

	struct FAnimation
	{
		/// Indexed by EAnimChannel.
		FAnimChannelTracks Channels[4];
		bool IsEmpty() const
		{
			for (const FAnimChannelTracks& C : Channels)
				if (!C.IsEmpty()) return false;
			return true;
		}
	};

	namespace Animation
	{
		constexpr const char* Format = "marchingblocks-animation";
		constexpr int SupportedVersion = 1;
		constexpr int FramesMax = 256;
		constexpr long long PixelsMax = 1LL << 26;
		constexpr double FpsMax = 60.0;
		constexpr double ScrollMax = 10.0;

		/// The English name of a channel in the format ("albedo", "normal", "orm", "emission").
		MARCHINGBLOCKSPAINT_API const char* ChannelName(EAnimChannel Channel);

		/// Reads extras.mb_animation: an empty animation when it is not one, or newer than this plugin. A value of the
		/// wrong type takes its default, a number out of range is clamped, unknown channels and tracks are ignored, a
		/// frames track without a frame and a pulse outside the emission do not exist.
		MARCHINGBLOCKSPAINT_API FAnimation Read(const FJsonValue& Value);

		/// The animation back in the format (normalized) — {} without one. What the conformance cases compare.
		MARCHINGBLOCKSPAINT_API FJsonValue ToJson(const FAnimation& Animation);

		/// The frame index at time T of a track of Count frames (0 without a frame). Phase in [0, 1[, 0 when synced.
		MARCHINGBLOCKSPAINT_API int FrameAt(int Count, double Fps, bool bPingPong, double T, double Phase);

		/// The emission factor at time T: 1 at the top, Minimum at the bottom; 1 when Frequency <= 0.
		MARCHINGBLOCKSPAINT_API double PulseAt(double Frequency, double Minimum, double T, double Phase);

		/// The UV offset at time T, written to OutU, OutV (added to the UVs; they repeat).
		MARCHINGBLOCKSPAINT_API void ScrollAt(double U, double V, double T, bool bSynced, double Phase, double& OutU, double& OutV);

		/// The phase of a tile whose ORIGIN (vertex + piece_offset) is at Ox, Oy, Oz in FORMAT space — in double
		/// precision (a 32-bit shader differs up to 0.025 on large origins: the plugin computes it per instance).
		MARCHINGBLOCKSPAINT_API double PhaseOf(double Ox, double Oy, double Oz);

		/// The JSON chunk of a .glb (12-byte header, then the first chunk's length and type "JSON"). False and Error
		/// when the bytes are not a glTF binary.
		MARCHINGBLOCKSPAINT_API bool ReadGlbJson(const std::vector<uint8_t>& Bytes, FJsonValue& Out, std::string& Error);

		/// Every material of a glTF document that carries an animation, by NAME. Materials of the same name are copies
		/// of one material: the first one read wins.
		MARCHINGBLOCKSPAINT_API std::map<std::string, FAnimation> ByMaterial(const FJsonValue& Gltf);
	}
}
