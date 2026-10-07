// MarchingBlocks Paint for Unreal — WHAT THE LOOKS SHARE: the plugin's materials (built by Tools/build_materials.py
// into Content/Materials), images kept in the level as PNG bytes (a packaged game has no .mbset folder), transient
// textures made from them, and the conversion between Unreal world space and FORMAT space that every MarchingBlocks
// shader needs (the rules — wind, blend, phase — are written in format space: right-handed, +Y up, 1 = a cell).

#pragma once

#include "CoreMinimal.h"
#include "MarchingBlocksLooks.generated.h"

class UMaterialInterface;
class UMaterialInstanceDynamic;
class UTexture2D;
class UTexture2DArray;

/** One image, kept as its PNG bytes (a level must rebuild without the exported folder). */
USTRUCT()
struct MARCHINGBLOCKSPAINT_API FMarchingBlocksImage
{
	GENERATED_BODY()

	/** Where it came from, relative to its folder (.mbset or .mbworld). */
	UPROPERTY()
	FString Path;

	UPROPERTY()
	TArray<uint8> Png;
};

namespace MarchingBlocksLooks
{
	/** The plugin's materials. */
	MARCHINGBLOCKSPAINT_API UMaterialInterface* AnimatedMaterial();
	MARCHINGBLOCKSPAINT_API UMaterialInterface* TransitionMaterial();
	MARCHINGBLOCKSPAINT_API UMaterialInterface* WindMaterial();
	/** One of the six water presets (stylized, clear, reflective, lava, swamp, acid); nullptr for an unknown look. */
	MARCHINGBLOCKSPAINT_API UMaterialInterface* WaterMaterial(const FString& Look);

	/** Reads a file into an image (false when it cannot be read). */
	MARCHINGBLOCKSPAINT_API bool LoadImageFile(const FString& FullPath, const FString& RelativePath, FMarchingBlocksImage& Out);

	/** Decodes PNG bytes to 8-bit BGRA, resized (nearest) to Width x Height when they differ. */
	MARCHINGBLOCKSPAINT_API bool DecodeBGRA(const TArray<uint8>& Png, int32& OutWidth, int32& OutHeight, TArray<FColor>& OutPixels);

	/** A transient texture array of the images, all brought to the size of the largest one. An image missing or
	 *  unreadable (nullptr) is a plain Missing slice — magenta by default: said on screen, never filled in. */
	MARCHINGBLOCKSPAINT_API UTexture2DArray* MakeArray(const TArray<const FMarchingBlocksImage*>& Images, bool bSRGB, UObject* Outer,
		FColor Missing = FColor(255, 0, 255, 255));

	/** Copies what an IMPORTED glTF material shows (its textures and factors, under the names glTF importers give them)
	 *  into a plugin material instance: MB_BaseColor_Still, MB_Normal_Still, MB_ORM_Still, MB_Emissive_Still (and their
	 *  _HasStill), MB_BaseColorFactor, MB_EmissiveFactor, MB_MetallicFactor, MB_RoughnessFactor, MB_EmissiveStrength.
	 *  Returns how many were found (0: nothing recognised — said by the caller). */
	MARCHINGBLOCKSPAINT_API int32 CopyImportedLook(UMaterialInterface* Imported, UMaterialInstanceDynamic* Mid);

	/** The glTF name of an imported material (importers add a prefix: "MI_", "M_"). */
	MARCHINGBLOCKSPAINT_API FString GltfNameOf(const UMaterialInterface* Imported);

	/** Writes the rows of the world -> format conversion of a frame into a MID ("MB_ToFormat0..2", "MB_ToWorld0..2"):
	 *  p_format = (dot(Row0.xyz, P) + Row0.w, …) for a world position P; ToWorld rows turn a format VECTOR back. */
	MARCHINGBLOCKSPAINT_API void SetFormatRows(UMaterialInstanceDynamic* Mid, const FMatrix& FormatToWorld);
}
