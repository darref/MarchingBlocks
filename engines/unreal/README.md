# MarchingBlocks — Unreal

- `MarchingBlocksPaint/` — the free Unreal plugin (see its README).
- `core-runner/` — runs the plugin's rule, tools, world-file reader and frame maths against `conformance.json`,
  `tools_conformance.json` and `world_conformance.json` OUTSIDE Unreal, with the constraints Unreal builds under (no exceptions, no RTTI,
  shadowing and narrowing as errors): `./build.sh`. It compiles the very files the plugin ships.
