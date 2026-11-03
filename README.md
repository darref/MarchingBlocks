# MarchingBlocks

**Sculpt one block. Paint a world.**

MarchingBlocks is a free and open-source tool for making **non-cubic 3D tilesets** and painting worlds with them. You
sculpt (or bring from Blender) a single *witness* block; MarchingBlocks slices it into every tile a marching-cubes
world needs, and you paint cells — the tiles follow. Worlds are layered: materials that touch blend through soft
transitions, water flows, foliage sways, textures animate. Then you export the tileset or the whole world to
**Godot, Unity or Unreal**, where the free *MarchingBlocks Paint* plugins keep painting it.

Workshops: Witness, World painting, Generate (whole islands, no AI), Preshape (41 parametric big shapes), Crossings
(stairs and slopes), Transitions, Fluids, Foliage, Animation, Variants, and a Play test with parallax relief.

## Download

Windows builds — the installer, a portable zip, the three engine plugins and the example world — are on the
**[Releases page](https://github.com/darref/MarchingBlocks/releases)**. The app tells you when a newer release is
out (it can be switched off in *Project*), and downloads the example world from there when you first open it.

## Support MarchingBlocks

MarchingBlocks is free and made by one developer. If it helps you build your worlds, a donation keeps it going:

- **Ko-fi** — https://ko-fi.com/darref
- **GitHub Sponsors** — https://github.com/sponsors/darref

## Build from source

1. Install [Godot 4.7 stable](https://godotengine.org/download) and its export templates.
2. `git clone --recursive https://github.com/darref/MarchingBlocks` (godot-cpp is a submodule).
3. Open the folder in Godot: the app is `app/editor.tscn`. The native core is prebuilt in
   `addons/marchingblocks_core/natif/bin/` for Windows and Linux; to rebuild it, see `gdextension/README.md`
   (`scons platform=windows target=template_release`, Python and a C++17 compiler).
4. The test suites: `bash DEV_TOOLS/lancer_les_suites.sh` (Git Bash). The whole release — suites, export,
   installer, plugins, example: `bash DEV_TOOLS/exporter_marchingblocks.sh` (the installer needs Inno Setup; without
   it, everything else is built).

The engine plugins live in `addons/marchingblocks_paint` (Godot), `engines/unity/com.marchingblocks.paint` (Unity)
and `engines/unreal/MarchingBlocksPaint` (Unreal). Most comments and design notes are written in French.

## License

- **The MarchingBlocks app** — and everything in this repository unless a license file next to it says otherwise —
  is free software under the **[GNU General Public License v3.0](LICENSE)**. You may use it for anything,
  commercial work included; if you distribute a modified version, it must stay under the GPL with its source.
- **The worlds and tilesets you make** with MarchingBlocks are yours, under any license you choose.
- **The three engine plugins** are under the **MIT License** (their own `LICENSE` files), so games built with them
  carry no GPL obligation.
- **The MarchingBlocks name and logo** are trademarks of SpannerGames: a modified version you distribute must use
  its own name and logo.
- Third-party components (Godot Engine, godot-cpp…) keep their own licenses: see *About → Third-party notices* in
  the app, or `THIRD_PARTY_NOTICES.txt` next to it.

© 2026 SpannerGames
