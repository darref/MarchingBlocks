// MarchingBlocks Paint for Unreal — a minimal JSON reader, in standard C++.
//
// The placement rule and the tools are standard C++ with no Unreal dependency, so the very same files
// are proven outside Unreal against conformance.json and tools_conformance.json (see core-runner).
// No exceptions and no RTTI: Unreal builds without either.

#pragma once

#include <cmath>
#include <cstdint>
#include <string>
#include <utility>
#include <vector>

namespace MBPaint
{
	struct FJsonValue
	{
		enum class EType { Null, Bool, Integer, Real, String, Array, Object };

		EType Type = EType::Null;
		bool Bool = false;
		int64_t Integer = 0;
		double Real = 0.0;
		std::string String;
		std::vector<FJsonValue> Array;
		// An object keeps its keys in order; lookups are linear, and the manifests are small.
		std::vector<std::pair<std::string, FJsonValue>> Object;

		bool IsNull() const { return Type == EType::Null; }
		bool IsNumber() const { return Type == EType::Integer || Type == EType::Real; }

		/// Numbers may be written 3 or 3.0 by different writers: both read as either.
		int64_t AsInt() const { return Type == EType::Integer ? Integer : static_cast<int64_t>(Real); }
		double AsReal() const { return Type == EType::Integer ? static_cast<double>(Integer) : Real; }

		/// nullptr when absent or when this is not an object.
		const FJsonValue* Find(const std::string& Key) const;
		/// A shared null value when absent: chains like V["a"]["b"] never crash.
		const FJsonValue& operator[](const std::string& Key) const;
		const FJsonValue& operator[](size_t Index) const;
		size_t Size() const { return Type == EType::Array ? Array.size() : Object.size(); }

		/// An integer, or a real without a fractional part (a writer may write 3 or 3.0).
		bool IsWhole() const { return Type == EType::Integer || (Type == EType::Real && std::isfinite(Real) && std::floor(Real) == Real); }

		// ── Building values (what a reader gives back, normalized) ──
		static FJsonValue MakeBool(bool B) { FJsonValue V; V.Type = EType::Bool; V.Bool = B; return V; }
		static FJsonValue MakeInt(int64_t I) { FJsonValue V; V.Type = EType::Integer; V.Integer = I; return V; }
		static FJsonValue MakeReal(double R) { FJsonValue V; V.Type = EType::Real; V.Real = R; return V; }
		static FJsonValue MakeString(const std::string& S) { FJsonValue V; V.Type = EType::String; V.String = S; return V; }
		static FJsonValue MakeArray() { FJsonValue V; V.Type = EType::Array; return V; }
		static FJsonValue MakeObject() { FJsonValue V; V.Type = EType::Object; return V; }
		/// Appends to an array.
		FJsonValue& Push(FJsonValue V) { Array.push_back(std::move(V)); return *this; }
		/// Sets a key of an object (replaces it when present).
		FJsonValue& Set(const std::string& Key, FJsonValue V)
		{
			for (auto& Entry : Object)
				if (Entry.first == Key) { Entry.second = std::move(V); return *this; }
			Object.emplace_back(Key, std::move(V));
			return *this;
		}
	};

	/// Parses Text into Out. Returns false and sets Error when the text is not valid JSON.
	bool ParseJson(const std::string& Text, FJsonValue& Out, std::string& Error);
}
