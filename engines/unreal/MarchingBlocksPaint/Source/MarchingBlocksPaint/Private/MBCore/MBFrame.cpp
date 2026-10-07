// MarchingBlocks Paint for Unreal — the frame (see MBFrame.h).

#include "MBCore/MBFrame.h"

#include <cmath>
#include <limits>

namespace MBPaint
{
	namespace FrameDetail
	{
		FVec3 Cross(const FVec3& A, const FVec3& B)
		{
			return FVec3(A.Y * B.Z - A.Z * B.Y, A.Z * B.X - A.X * B.Z, A.X * B.Y - A.Y * B.X);
		}

		double Dot(const FVec3& A, const FVec3& B) { return A.X * B.X + A.Y * B.Y + A.Z * B.Z; }
	}

	double FVec3::Length() const { return std::sqrt(X * X + Y * Y + Z * Z); }

	bool FFrame::Measure(const std::vector<FVec3>& MarkerVertices, FFrame& Out, std::string& Error)
	{
		std::vector<FVec3> Points;
		double Unit = std::numeric_limits<double>::max();
		for (const FVec3& P : MarkerVertices)
		{
			const double L = P.Length();
			if (L > 1e-4) { Points.push_back(P); Unit = std::fmin(Unit, L); }
		}
		if (Points.empty()) { Error = "the frame marker is empty"; return false; }
		FVec3 Axes[3];
		bool bFound[3] = {false, false, false};
		for (const FVec3& P : Points)
		{
			// Lengths 1, 2, 3 tell the axes apart: x, y, z.
			const long Axis = std::lround(P.Length() / Unit) - 1;
			if (Axis < 0 || Axis > 2) { Error = "the frame marker is not the one MarchingBlocks writes"; return false; }
			const size_t A = static_cast<size_t>(Axis);
			Axes[A] = P * (1.0 / static_cast<double>(A + 1));
			bFound[A] = true;
		}
		if (!bFound[0] || !bFound[1] || !bFound[2]) { Error = "the frame marker lost a point on import"; return false; }
		Out.AxisX = Axes[0];
		Out.AxisY = Axes[1];
		Out.AxisZ = Axes[2];
		Out.Unit = Unit;
		return true;
	}

	FVec3 FFrame::ToImported(const FVec3& P) const
	{
		return AxisX * P.X + AxisY * P.Y + AxisZ * P.Z;
	}

	FVec3 FFrame::ToFormat(const FVec3& Q) const
	{
		// The rows of F⁻¹ are the cross products of the columns, over the determinant.
		const double Det = FrameDetail::Dot(AxisX, FrameDetail::Cross(AxisY, AxisZ));
		return FVec3(FrameDetail::Dot(FrameDetail::Cross(AxisY, AxisZ), Q) / Det,
			FrameDetail::Dot(FrameDetail::Cross(AxisZ, AxisX), Q) / Det,
			FrameDetail::Dot(FrameDetail::Cross(AxisX, AxisY), Q) / Det);
	}

	bool FFrame::IsMirrored() const
	{
		return FrameDetail::Dot(AxisX, FrameDetail::Cross(AxisY, AxisZ)) < 0.0;
	}

	std::array<FVec3, 3> FFrame::QuarterTurn(int QuarterTurns) const
	{
		const int Q = ((QuarterTurns % 4) + 4) % 4;
		// Exact values: a quarter turn must not carry the rounding of cos(pi / 2).
		return TurnCosSin(Q == 0 ? 1.0 : Q == 2 ? -1.0 : 0.0, Q == 1 ? 1.0 : Q == 3 ? -1.0 : 0.0);
	}

	std::array<FVec3, 3> FFrame::Turn(double Radians) const
	{
		return TurnCosSin(std::cos(Radians), std::sin(Radians));
	}

	std::array<FVec3, 3> FFrame::TurnCosSin(double C, double S) const
	{
		std::array<FVec3, 3> Images;
		const FVec3 Units[3] = {FVec3(1, 0, 0), FVec3(0, 1, 0), FVec3(0, 0, 1)};
		for (size_t I = 0; I < 3; ++I)
		{
			const FVec3 U = ToFormat(Units[I]);
			// x' = c·x + s·z ; z' = −s·x + c·z   →   a quarter turn sends +Z (0,0,1) to +X (1,0,0).
			const FVec3 R(C * U.X + S * U.Z, U.Y, -S * U.X + C * U.Z);
			Images[I] = ToImported(R);
		}
		return Images;
	}
}
