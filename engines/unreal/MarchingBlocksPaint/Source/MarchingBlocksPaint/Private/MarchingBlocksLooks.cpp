// MarchingBlocks Paint for Unreal — ce que les rendus partagent (voir MarchingBlocksLooks.h).

#include "MarchingBlocksLooks.h"

#include "Engine/Texture.h"
#include "Engine/Texture2D.h"
#include "Engine/Texture2DArray.h"
#include "IImageWrapper.h"
#include "IImageWrapperModule.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Materials/MaterialInterface.h"
#include "Misc/FileHelper.h"
#include "Modules/ModuleManager.h"

namespace MarchingBlocksLooks
{
	namespace
	{
		UMaterialInterface* LooksLoadPluginMaterial(const TCHAR* Name)
		{
			const FString Path = FString::Printf(TEXT("/MarchingBlocksPaint/Materials/%s.%s"), Name, Name);
			return LoadObject<UMaterialInterface>(nullptr, *Path, nullptr, LOAD_NoWarn | LOAD_Quiet);
		}
	}

	UMaterialInterface* AnimatedMaterial() { return LooksLoadPluginMaterial(TEXT("M_MB_Animated")); }
	UMaterialInterface* TransitionMaterial() { return LooksLoadPluginMaterial(TEXT("M_MB_Transition")); }
	UMaterialInterface* WindMaterial() { return LooksLoadPluginMaterial(TEXT("M_MB_Wind")); }

	UMaterialInterface* WaterMaterial(const FString& Look)
	{
		static const TCHAR* Looks[] = {TEXT("stylized"), TEXT("clear"), TEXT("reflective"), TEXT("lava"), TEXT("swamp"), TEXT("acid")};
		for (const TCHAR* L : Looks)
			if (Look.Equals(L, ESearchCase::IgnoreCase))
				return LooksLoadPluginMaterial(*FString::Printf(TEXT("M_MB_Water_%s"), L));
		return nullptr;
	}

	bool LoadImageFile(const FString& FullPath, const FString& RelativePath, FMarchingBlocksImage& Out)
	{
		Out.Path = RelativePath;
		Out.Png.Reset();
		return FFileHelper::LoadFileToArray(Out.Png, *FullPath);
	}

	bool DecodeBGRA(const TArray<uint8>& Png, int32& OutWidth, int32& OutHeight, TArray<FColor>& OutPixels)
	{
		if (Png.Num() == 0) return false;
		IImageWrapperModule& Module = FModuleManager::LoadModuleChecked<IImageWrapperModule>(TEXT("ImageWrapper"));
		const EImageFormat Format = Module.DetectImageFormat(Png.GetData(), Png.Num());
		if (Format == EImageFormat::Invalid) return false;
		TSharedPtr<IImageWrapper> Wrapper = Module.CreateImageWrapper(Format);
		if (!Wrapper.IsValid() || !Wrapper->SetCompressed(Png.GetData(), Png.Num())) return false;
		TArray<uint8> Raw;
		if (!Wrapper->GetRaw(ERGBFormat::BGRA, 8, Raw)) return false;
		OutWidth = static_cast<int32>(Wrapper->GetWidth());
		OutHeight = static_cast<int32>(Wrapper->GetHeight());
		OutPixels.SetNumUninitialized(OutWidth * OutHeight);
		FMemory::Memcpy(OutPixels.GetData(), Raw.GetData(), FMath::Min<int64>(Raw.Num(), OutPixels.Num() * 4));
		return OutWidth > 0 && OutHeight > 0;
	}

	UTexture2DArray* MakeArray(const TArray<const FMarchingBlocksImage*>& Images, bool bSRGB, UObject* Outer, FColor Missing)
	{
		struct FDecoded { int32 W = 0; int32 H = 0; TArray<FColor> Pixels; };
		TArray<FDecoded> Decoded;
		int32 W = 0, H = 0;
		for (const FMarchingBlocksImage* Image : Images)
		{
			FDecoded D;
			if (Image && DecodeBGRA(Image->Png, D.W, D.H, D.Pixels))
			{
				W = FMath::Max(W, D.W);
				H = FMath::Max(H, D.H);
			}
			else D.W = D.H = 0;
			Decoded.Add(MoveTemp(D));
		}
		if (Decoded.Num() == 0) return nullptr;
		W = FMath::Max(W, 4);
		H = FMath::Max(H, 4);
		TArray<TArray<FColor>> Slices;
		for (FDecoded& D : Decoded)
		{
			TArray<FColor> Pixels;
			Pixels.SetNumUninitialized(W * H);
			for (int32 Y = 0; Y < H; ++Y)
				for (int32 X = 0; X < W; ++X)
					// Brought to the common size (nearest): an array has one size.
					Pixels[Y * W + X] = D.W > 0 ? D.Pixels[(Y * D.H / H) * D.W + (X * D.W / W)] : Missing;
			Slices.Add(MoveTemp(Pixels));
		}
		if (Slices.Num() == 0 || W == 0) return nullptr;
		UTexture2DArray* Array = UTexture2DArray::CreateTransient(W, H, Slices.Num(), PF_B8G8R8A8);
		if (!Array) return nullptr;
		Array->SRGB = bSRGB;
		Array->Filter = TF_Bilinear;
		Array->AddressX = TA_Wrap;
		Array->AddressY = TA_Wrap;
		FTexture2DMipMap& Mip = Array->GetPlatformData()->Mips[0];
		uint8* Data = static_cast<uint8*>(Mip.BulkData.Lock(LOCK_READ_WRITE));
		const int64 SliceBytes = static_cast<int64>(W) * H * 4;
		for (int32 S = 0; S < Slices.Num(); ++S) FMemory::Memcpy(Data + SliceBytes * S, Slices[S].GetData(), SliceBytes);
		Mip.BulkData.Unlock();
		Array->UpdateResource();
		return Array;
	}

	namespace
	{
		UTexture* LooksTextureOf(UMaterialInterface* M, std::initializer_list<const TCHAR*> Names)
		{
			for (const TCHAR* N : Names)
			{
				UTexture* T = nullptr;
				if (M->GetTextureParameterValue(FHashedMaterialParameterInfo(FName(N)), T) && T) return T;
			}
			return nullptr;
		}

		bool LooksScalarOf(UMaterialInterface* M, std::initializer_list<const TCHAR*> Names, float& Out)
		{
			for (const TCHAR* N : Names)
				if (M->GetScalarParameterValue(FHashedMaterialParameterInfo(FName(N)), Out)) return true;
			return false;
		}

		bool LooksVectorOf(UMaterialInterface* M, std::initializer_list<const TCHAR*> Names, FLinearColor& Out)
		{
			for (const TCHAR* N : Names)
				if (M->GetVectorParameterValue(FHashedMaterialParameterInfo(FName(N)), Out)) return true;
			return false;
		}
	}

	FString GltfNameOf(const UMaterialInterface* Imported)
	{
		FString Name = Imported ? Imported->GetName() : FString();
		for (const TCHAR* Prefix : {TEXT("MI_"), TEXT("M_")})
			if (Name.StartsWith(Prefix, ESearchCase::CaseSensitive)) { Name.RightChopInline(FCString::Strlen(Prefix)); break; }
		return Name;
	}

	int32 CopyImportedLook(UMaterialInterface* Imported, UMaterialInstanceDynamic* Mid)
	{
		if (!Imported || !Mid) return 0;
		int32 Found = 0;
		struct FChannel { const TCHAR* Name; std::initializer_list<const TCHAR*> Textures; };
		const FChannel Channels[4] = {
			{TEXT("BaseColor"), {TEXT("BaseColorTexture"), TEXT("BaseColor"), TEXT("Base Color Texture"), TEXT("DiffuseTexture")}},
			{TEXT("Normal"), {TEXT("NormalTexture"), TEXT("Normal")}},
			{TEXT("ORM"), {TEXT("MetallicRoughnessTexture"), TEXT("OcclusionRoughnessMetallicTexture"), TEXT("ORM")}},
			{TEXT("Emissive"), {TEXT("EmissiveTexture"), TEXT("Emissive")}},
		};
		for (const FChannel& C : Channels)
			if (UTexture* Still = LooksTextureOf(Imported, C.Textures))
			{
				const FString P = FString(TEXT("MB_")) + C.Name;
				Mid->SetTextureParameterValue(*(P + TEXT("_Still")), Still);
				Mid->SetScalarParameterValue(*(P + TEXT("_HasStill")), 1.f);
				++Found;
			}
		FLinearColor Colour;
		if (LooksVectorOf(Imported, {TEXT("BaseColorFactor"), TEXT("BaseColor")}, Colour)) { Mid->SetVectorParameterValue(TEXT("MB_BaseColorFactor"), Colour); ++Found; }
		if (LooksVectorOf(Imported, {TEXT("EmissiveFactor"), TEXT("Emissive")}, Colour)) { Mid->SetVectorParameterValue(TEXT("MB_EmissiveFactor"), Colour); ++Found; }
		float Value = 0.f;
		if (LooksScalarOf(Imported, {TEXT("MetallicFactor"), TEXT("Metallic")}, Value)) { Mid->SetScalarParameterValue(TEXT("MB_MetallicFactor"), Value); ++Found; }
		if (LooksScalarOf(Imported, {TEXT("RoughnessFactor"), TEXT("Roughness")}, Value)) { Mid->SetScalarParameterValue(TEXT("MB_RoughnessFactor"), Value); ++Found; }
		if (LooksScalarOf(Imported, {TEXT("EmissiveStrength"), TEXT("Emissive Strength")}, Value)) { Mid->SetScalarParameterValue(TEXT("MB_EmissiveStrength"), Value); ++Found; }
		if (LooksScalarOf(Imported, {TEXT("AlphaCutoff"), TEXT("Alpha Cutoff")}, Value)) { Mid->SetScalarParameterValue(TEXT("MB_AlphaCutoff"), Value); ++Found; }
		return Found;
	}

	void SetFormatRows(UMaterialInstanceDynamic* Mid, const FMatrix& FormatToWorld)
	{
		if (!Mid) return;
		// Unreal multiplies ROW vectors: P_world = p_format * FormatToWorld. Its inverse sends a world point back.
		const FMatrix ToFormat = FormatToWorld.Inverse();
		for (int32 C = 0; C < 3; ++C)
		{
			// p_format[C] = sum_r P[r] * ToFormat[r][C] + ToFormat[3][C].
			const FLinearColor Row(ToFormat.M[0][C], ToFormat.M[1][C], ToFormat.M[2][C], ToFormat.M[3][C]);
			Mid->SetVectorParameterValue(*FString::Printf(TEXT("MB_ToFormat%d"), C), Row);
			// v_world[C] = sum_k v_format[k] * FormatToWorld[k][C] (a VECTOR: no translation).
			const FLinearColor Back(FormatToWorld.M[0][C], FormatToWorld.M[1][C], FormatToWorld.M[2][C], 0.f);
			Mid->SetVectorParameterValue(*FString::Printf(TEXT("MB_ToWorld%d"), C), Back);
		}
	}
}
