// MarchingBlocks Paint for Unreal — THE FRAME: from the tileset's format space to the imported meshes.
//
// Unreal is left-handed, +Z up, in centimetres; glTF is right-handed, +Y up, in metres, and every glTF
// importer converts in its own way. This file does not guess: tiles.glb carries a marker whose vertices
// are exactly (0,0,0), (1,0,0), (0,2,0), (0,0,3) in format space. Wherever the importer put them, their
// lengths 1, 2, 3 tell the axes apart: that linear map F IS the conversion (mirror and units included),
// and the cell grid goes through the very same map.
//
// Standard C++, no Unreal dependency: core-runner proves it on a mirrored, centimetre frame.

#pragma once

#include <array>
#include <string>
#include <vector>

namespace MBPaint
{
	struct FVec3
	{
		double X = 0.0;
		double Y = 0.0;
		double Z = 0.0;

		FVec3() = default;
		FVec3(double InX, double InY, double InZ) : X(InX), Y(InY), Z(InZ) {}
		FVec3 operator+(const FVec3& O) const { return FVec3(X + O.X, Y + O.Y, Z + O.Z); }
		FVec3 operator-(const FVec3& O) const { return FVec3(X - O.X, Y - O.Y, Z - O.Z); }
		FVec3 operator*(double S) const { return FVec3(X * S, Y * S, Z * S); }
		double Length() const;
	};

	class FFrame
	{
	public:
		/// Images of the format axes (columns of F), in the imported meshes' space. Unit included.
		FVec3 AxisX = FVec3(1, 0, 0);
		FVec3 AxisY = FVec3(0, 1, 0);
		FVec3 AxisZ = FVec3(0, 0, 1);
		/// Length of one format unit in the imported space (1 for metres, 100 for centimetres).
		double Unit = 1.0;

		/// Reads the marker's vertices as the importer placed them. Returns false and says why when they
		/// are not the marker MarchingBlocks writes.
		static bool Measure(const std::vector<FVec3>& MarkerVertices, FFrame& Out, std::string& Error);

		/// F(p): a format-space point in the imported space.
		FVec3 ToImported(const FVec3& P) const;
		/// F⁻¹(q): back to format space.
		FVec3 ToFormat(const FVec3& Q) const;
		bool IsMirrored() const;

		/// A quarter turn about format +Y (right-hand: +Z turns towards +X) seen in the imported space:
		/// F · R · F⁻¹, returned as the images of the imported space's unit X, Y, Z axes. Always a PROPER
		/// rotation (orthonormal, determinant +1), even when F mirrors — which a left-handed engine's F
		/// necessarily does.
		std::array<FVec3, 3> QuarterTurn(int QuarterTurns) const;

		/// The same for ANY angle about format +Y (a plant's yaw, in radians, right-hand): F · R(yaw) · F⁻¹, as the images
		/// of the imported space's unit axes. Turn(q pi / 2) is QuarterTurn(q).
		std::array<FVec3, 3> Turn(double Radians) const;

	private:
		std::array<FVec3, 3> TurnCosSin(double C, double S) const;
	};
}
