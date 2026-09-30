// MarchingBlocks Paint — the editor module. The editor mode (UMarchingBlocksEdMode) is a UEdMode: the
// editor finds and registers it by itself, and shows it in the Modes menu. This module registers the
// icons its panel draws: MarchingBlocks' own, Resources/Icons/<name>.png, as "MarchingBlocks.<name>".

#include "Brushes/SlateImageBrush.h"
#include "HAL/FileManager.h"
#include "Interfaces/IPluginManager.h"
#include "MarchingBlocksModeToolkit.h"
#include "Misc/Paths.h"
#include "Modules/ModuleManager.h"
#include "Styling/SlateStyle.h"
#include "Styling/SlateStyleRegistry.h"

class FMarchingBlocksPaintEditorModule : public IModuleInterface
{
public:
	virtual void StartupModule() override
	{
		TSharedPtr<IPlugin> Plugin = IPluginManager::Get().FindPlugin(TEXT("MarchingBlocksPaint"));
		if (!Plugin.IsValid()) return;
		const FString Folder = FPaths::Combine(Plugin->GetBaseDir(), TEXT("Resources"), TEXT("Icons"));
		Style = MakeShareable(new FSlateStyleSet(FMarchingBlocksModeToolkit::StyleName));
		Style->SetContentRoot(Folder);
		// Every icon on disk, by its file name: the generator decides which exist, not a second list here.
		TArray<FString> Files;
		IFileManager::Get().FindFiles(Files, *FPaths::Combine(Folder, TEXT("*.png")), true, false);
		for (const FString& File : Files)
			Style->Set(FName(TEXT("MarchingBlocks.") + FPaths::GetBaseFilename(File)),
				new FSlateImageBrush(FPaths::Combine(Folder, File), FVector2D(20.0, 20.0)));
		FSlateStyleRegistry::RegisterSlateStyle(*Style);
	}

	virtual void ShutdownModule() override
	{
		if (Style.IsValid()) FSlateStyleRegistry::UnRegisterSlateStyle(*Style);
		Style.Reset();
	}

private:
	TSharedPtr<FSlateStyleSet> Style;
};

IMPLEMENT_MODULE(FMarchingBlocksPaintEditorModule, MarchingBlocksPaintEditor)
