# Unity test project

Proves the Unity package on the REAL witness, through the REAL glTF importer (glTFast):

1. `godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/preparer_essai_unity.gd`
   exports the witness tileset into `Assets/`, with its cells and what MarchingBlocks places on them, and a
   three-layer painted world (`witness_world.mbworld`) with what MarchingBlocks places on each layer.
2. `Unity.exe -batchmode -nographics -projectPath . -runTests -testPlatform EditMode -testResults results.xml`
   runs the package's conformance and aim tests, `Assets/Tests/Editor/WitnessTests.cs`, `WorldImportTests.cs`
   and `AimKeysTests.cs` (Tab and Space through the Scene-view editor itself).
3. `godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/preparer_eau_unity.gd` exports the WATER world
   (`water_world.mbworld`, three water layers with their baked sheets, and `water_world_expected.json`): the rebuilt water
   is checked against it (`WaterRebuildTests.cs`), and `-executeMethod WaterCaptures.CaptureAll -mbOut <folder>` draws the
   baked and the rebuilt sheets under the six looks.

⚠ The tests that judge a PICTURE (ParityWorldTests) need a GPU: run them WITHOUT `-nographics` (with it they read black).
