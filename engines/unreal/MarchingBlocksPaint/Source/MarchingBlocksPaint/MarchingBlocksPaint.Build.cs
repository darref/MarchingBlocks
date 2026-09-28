// MarchingBlocks Paint — the runtime module: the rule, the tools, and the world actor.

using UnrealBuildTool;

public class MarchingBlocksPaint : ModuleRules
{
	public MarchingBlocksPaint(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine" });
		if (Target.bBuildEditor)
		{
			// Undo transactions and the asset registry, for the editor only.
			PrivateDependencyModuleNames.AddRange(new string[] { "UnrealEd", "AssetRegistry", "MeshDescription", "StaticMeshDescription" });
		}
	}
}
