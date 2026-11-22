# NOVEXA Generals Mac

*Command Your Legacy. Native on Mac.*

## ⬇️ Download for players
**Get the launcher at [play.novexa-jo.com/download](https://play.novexa-jo.com/download)** — website: **[play.novexa-jo.com](https://play.novexa-jo.com)**

Requires a Mac with Apple Silicon (M1 or newer) and your own copy of *C&C Generals / Zero Hour*
(the launcher can download it from your Steam account). Online play signs in with Discord.

> NOVEXA is not affiliated with, endorsed by, or sponsored by Electronic Arts Inc. Command & Conquer,
> Generals and Zero Hour are trademarks of Electronic Arts Inc., used only to describe compatibility.

This repository is the complete source code (GPL-3.0 with EA's additional terms). Building it yourself is optional.

A native macOS (Apple Silicon) launcher and build of an open-source engine for
**Command & Conquer: Generals** and **Zero Hour**, using game files you already own.

## What it is — honestly
* **Engine:** [GeneralsX](https://github.com/fbraz3/GeneralsX), a community port of EA's GPL-3.0 source release,
  compiled here as a **native arm64 Mach-O** binary. No Wine, no Rosetta, no virtual machine, no Windows executables.
* **Graphics:** the engine's Direct3D 8 calls are translated by DXVK → Vulkan → MoltenVK → **Metal**.
  This is a translation chain, not a hand-written Metal renderer.
* **Launcher:** Swift/SwiftUI app (this repo) handling installation detection & validation, launching and
  monitoring, mods, backups and diagnostics.
* **No game data is included or downloaded.** Bring your own copy (Steam, EA App, The First Decade, retail).

## Status
See [PROJECT_STATUS.md](PROJECT_STATUS.md). Gameplay has **not yet been verified** on this machine because no game files are present.

## Build
```bash
git submodule update --init
brew install cmake ninja meson pkgconf vcpkg molten-vk vulkan-loader vulkan-headers glslang libpng
git clone https://github.com/microsoft/vcpkg engine/deps/vcpkg && engine/deps/vcpkg/bootstrap-vcpkg.sh -disableMetrics
./scripts/build-engine.sh zh          # GeneralsXZH (Zero Hour); "generals" for the base game
./scripts/stage-engine.sh zeroHour    # copy engine + dylibs to build/runtime/zeroHour
./scripts/bundle-app.sh               # build/NOVEXA Generals Mac.app
```
Details: [docs/BUILD.md](docs/BUILD.md).

## Docs
[Environment](docs/ENVIRONMENT.md) · [Research](docs/RESEARCH.md) · [Architecture](docs/ARCHITECTURE.md) ·
[Engine](docs/ENGINE.md) · [Graphics](docs/GRAPHICS.md) · [Installation](docs/INSTALLATION.md) · [Mods](docs/MODS.md) ·
[Security & legal](docs/SECURITY.md) · [Testing](docs/TESTING.md) · [Troubleshooting](docs/TROUBLESHOOTING.md) · [Roadmap](docs/ROADMAP.md)

## License
GPL-3.0-or-later (see LICENSE, inherited from EA's source release). Not affiliated with or endorsed by Electronic Arts.
Command & Conquer is a trademark of Electronic Arts Inc.
