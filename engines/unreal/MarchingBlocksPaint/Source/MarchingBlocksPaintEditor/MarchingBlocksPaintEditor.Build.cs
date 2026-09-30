// MarchingBlocks Paint — the editor module: the "MarchingBlocks" editor mode (aiming, strokes, preview).

using UnrealBuildTool;

public class MarchingBlocksPaintEditor : ModuleRules
{
	public MarchingBlocksPaintEditor(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PrivateDependencyModuleNames.AddRange(new string[]
		{
			"Core", "CoreUObject", "Engine", "InputCore", "Slate", "SlateCore", "UnrealEd", "EditorFramework", "Projects",
			"MarchingBlocksPaint",
		});
	}
}
