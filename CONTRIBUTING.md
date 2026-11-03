# Contributing to MarchingBlocks

Thanks for your interest! Bug reports, ideas and pull requests are welcome, in English or French.

## Reporting a bug

Open an issue with:

- your OS, the MarchingBlocks version (**About** box) and how you run it (release build or from source);
- what you did, what you expected, what happened;
- if possible, a small `.mbproj` project that shows it, and the log
  (`%APPDATA%\Godot\app_userdata\MarchingBlocks\logs\godot.log` on Windows).

## Pull requests

1. Fork, create a branch, keep the change focused on one thing.
2. Run the test suites that cover what you touched (see the README, *Tests*), and say in the PR which ones you ran.
   A change to a rule (placement, tools, water…) must keep the shared conformance cases green in **all three**
   plugins, or regenerate them with `DEV_TOOLS/generer_cas_d_epreuve.gd`.
3. A new behaviour comes with a test that you have **seen fail** without your change.
4. Screen text is English; code comments may be French or English.

## Project rules worth knowing

The project charter, `CLAUDE.md` (in French), records the design decisions and why they were taken. A few that
matter for contributors:

- **One rule, one place.** The placement rule lives in `addons/marchingblocks_core/marching_blocks.gd`; the
  plugins reimplement it from the written rule in the format and are judged by the conformance cases, never by
  copying code.
- **The GDScript is the reference.** The native core (`gdextension/`) must return exactly what the GDScript
  returns (`DEV_TOOLS/test_natif.gd`). If you change a ported function, port the change to C++.
- **Nothing is filled in silently.** A missing tile shows as a red cube; the tool never invents geometry the
  artist did not make.

## License

By contributing, you agree that your contribution is released under the project's [MIT License](LICENSE).
