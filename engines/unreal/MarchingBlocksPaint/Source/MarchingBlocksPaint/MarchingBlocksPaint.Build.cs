// MarchingBlocks Paint — the runtime module: the rule, the tools, and the world actor.

using UnrealBuildTool;

public class MarchingBlocksPaint : ModuleRules
{
	public MarchingBlocksPaint(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine" });
		// PNG frames and representatives kept in the level, decoded into transient textures (in game too).
		PrivateDependencyModuleNames.AddRange(new string[] { "ImageWrapper", "RenderCore" });
		// The water sheet rebuilt when you paint: a static mesh built from a mesh description (in game too).
		PrivateDependencyModuleNames.AddRange(new string[] { "MeshDescription", "StaticMeshDescription" });
		if (Target.bBuildEditor)
		{
			// Undo transactions and the asset registry, for the editor only.
			PrivateDependencyModuleNames.AddRange(new string[] { "UnrealEd", "AssetRegistry" });
		}
	}
}
