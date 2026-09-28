# MarchingBlocks — Unity

- `com.marchingblocks.paint/` — the free Unity package (see its README).
- `conformance-runner/` — runs the package's placement rule against `conformance.json`, and its editing
  tools against `tools_conformance.json`, with the .NET SDK, outside Unity: `dotnet run -c Release`.
  It compiles the very files the package ships.
- `test-project/` — the package on the real witness, through glTFast, in Unity's Test Runner.
