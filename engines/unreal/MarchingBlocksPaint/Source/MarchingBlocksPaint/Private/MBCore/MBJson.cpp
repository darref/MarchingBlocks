// MarchingBlocks Paint for Unreal — the JSON reader (see MBJson.h).

#include "MBCore/MBJson.h"

#include <cstdlib>

namespace MBPaint
{
	namespace JsonDetail
	{
		const FJsonValue& NullValue()
		{
			static const FJsonValue Null;
			return Null;
		}

		struct FReader
		{
			const std::string& S;
			size_t I = 0;
			std::string Error;

			explicit FReader(const std::string& InText) : S(InText) {}

			bool Fail(const char* What)
			{
				if (Error.empty()) Error = std::string(What) + " at " + std::to_string(I);
				return false;
			}

			void SkipSpace()
			{
				while (I < S.size() && (S[I] == ' ' || S[I] == '\t' || S[I] == '\n' || S[I] == '\r')) ++I;
			}

			bool Word(const char* W, size_t Length)
			{
				if (S.compare(I, Length, W) != 0) return Fail("unexpected token");
				I += Length;
				return true;
			}

			static void AppendUtf8(std::string& Out, uint32_t C)
			{
				if (C < 0x80) Out += static_cast<char>(C);
				else if (C < 0x800)
				{
					Out += static_cast<char>(0xC0 | (C >> 6));
					Out += static_cast<char>(0x80 | (C & 0x3F));
				}
				else
				{
					Out += static_cast<char>(0xE0 | (C >> 12));
					Out += static_cast<char>(0x80 | ((C >> 6) & 0x3F));
					Out += static_cast<char>(0x80 | (C & 0x3F));
				}
			}

			bool ReadString(std::string& Out)
			{
				++I; // opening quote
				while (I < S.size())
				{
					const char C = S[I++];
					if (C == '"') return true;
					if (C != '\\') { Out += C; continue; }
					if (I >= S.size()) break;
					const char E = S[I++];
					switch (E)
					{
					case '"': Out += '"'; break;
					case '\\': Out += '\\'; break;
					case '/': Out += '/'; break;
					case 'b': Out += '\b'; break;
					case 'f': Out += '\f'; break;
					case 'n': Out += '\n'; break;
					case 'r': Out += '\r'; break;
					case 't': Out += '\t'; break;
					case 'u':
					{
						if (I + 4 > S.size()) return Fail("bad \\u escape");
						const std::string Hex = S.substr(I, 4);
						I += 4;
						AppendUtf8(Out, static_cast<uint32_t>(std::strtoul(Hex.c_str(), nullptr, 16)));
						break;
					}
					default: return Fail("bad escape");
					}
				}
				return Fail("unterminated string");
			}

			bool ReadNumber(FJsonValue& Out)
			{
				const size_t Start = I;
				bool bReal = false;
				while (I < S.size())
				{
					const char C = S[I];
					if (C == '.' || C == 'e' || C == 'E') bReal = true;
					else if (!(C == '+' || C == '-' || (C >= '0' && C <= '9'))) break;
					++I;
				}
				if (I == Start) return Fail("unexpected character");
				const std::string Text = S.substr(Start, I - Start);
				if (bReal)
				{
					Out.Type = FJsonValue::EType::Real;
					Out.Real = std::strtod(Text.c_str(), nullptr);
				}
				else
				{
					Out.Type = FJsonValue::EType::Integer;
					Out.Integer = std::strtoll(Text.c_str(), nullptr, 10);
				}
				return true;
			}

			bool ReadValue(FJsonValue& Out, int Depth)
			{
				if (Depth > 256) return Fail("too deeply nested");
				SkipSpace();
				if (I >= S.size()) return Fail("unexpected end");
				const char C = S[I];
				if (C == '{')
				{
					Out.Type = FJsonValue::EType::Object;
					++I;
					SkipSpace();
					if (I < S.size() && S[I] == '}') { ++I; return true; }
					while (true)
					{
						SkipSpace();
						if (I >= S.size() || S[I] != '"') return Fail("expected a key");
						std::string Key;
						if (!ReadString(Key)) return false;
						SkipSpace();
						if (I >= S.size() || S[I] != ':') return Fail("expected ':'");
						++I;
						Out.Object.emplace_back(std::move(Key), FJsonValue());
						if (!ReadValue(Out.Object.back().second, Depth + 1)) return false;
						SkipSpace();
						if (I < S.size() && S[I] == ',') { ++I; continue; }
						if (I < S.size() && S[I] == '}') { ++I; return true; }
						return Fail("expected ',' or '}'");
					}
				}
				if (C == '[')
				{
					Out.Type = FJsonValue::EType::Array;
					++I;
					SkipSpace();
					if (I < S.size() && S[I] == ']') { ++I; return true; }
					while (true)
					{
						Out.Array.emplace_back();
						if (!ReadValue(Out.Array.back(), Depth + 1)) return false;
						SkipSpace();
						if (I < S.size() && S[I] == ',') { ++I; continue; }
						if (I < S.size() && S[I] == ']') { ++I; return true; }
						return Fail("expected ',' or ']'");
					}
				}
				if (C == '"')
				{
					Out.Type = FJsonValue::EType::String;
					return ReadString(Out.String);
				}
				if (C == 't') { Out.Type = FJsonValue::EType::Bool; Out.Bool = true; return Word("true", 4); }
				if (C == 'f') { Out.Type = FJsonValue::EType::Bool; Out.Bool = false; return Word("false", 5); }
				if (C == 'n') { Out.Type = FJsonValue::EType::Null; return Word("null", 4); }
				return ReadNumber(Out);
			}
		};
	}

	const FJsonValue* FJsonValue::Find(const std::string& Key) const
	{
		if (Type != EType::Object) return nullptr;
		for (const auto& Entry : Object)
			if (Entry.first == Key) return &Entry.second;
		return nullptr;
	}

	const FJsonValue& FJsonValue::operator[](const std::string& Key) const
	{
		const FJsonValue* Found = Find(Key);
		return Found ? *Found : JsonDetail::NullValue();
	}

	const FJsonValue& FJsonValue::operator[](size_t Index) const
	{
		return Type == EType::Array && Index < Array.size() ? Array[Index] : JsonDetail::NullValue();
	}

	bool ParseJson(const std::string& Text, FJsonValue& Out, std::string& Error)
	{
		JsonDetail::FReader Reader(Text);
		Out = FJsonValue();
		if (!Reader.ReadValue(Out, 0)) { Error = Reader.Error; return false; }
		Reader.SkipSpace();
		if (Reader.I != Text.size()) { Error = "unexpected character at " + std::to_string(Reader.I); return false; }
		return true;
	}
}
