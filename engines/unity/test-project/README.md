# Unity test project

Proves the Unity package on the REAL witness, through the REAL glTF importer (glTFast):

1. `godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/preparer_essai_unity.gd`
   exports the witness tileset into `Assets/`, with its cells and what MarchingBlocks places on them.
2. `Unity.exe -batchmode -nographics -projectPath . -runTests -testPlatform EditMode -testResults results.xml`
   runs the package's conformance tests and `Assets/Tests/Editor/WitnessTests.cs`.
