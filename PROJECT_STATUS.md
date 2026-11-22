# Project status — 2026-11-22

**Current milestone:** 6 — skirmish playable in both Generals and Zero Hour (user-verified). Remaining: AI/audio/perf confirmation, fullscreen, online service config.

## Done
* M1 environment: inspected and documented (docs/ENVIRONMENT.md); toolchain installed via Homebrew.
* M2 research: GeneralsX chosen (docs/RESEARCH.md); added as git submodule at commit 6a71368.
* M3 native build: `GeneralsXZH` builds as Mach-O **arm64**; DXVK d3d8/d3d9, SDL3, SDL3_image, MoltenVK,
  Vulkan loader, gamespy all arm64. Engine executes and initialises its filesystems (headless smoke test).
* M7 launcher: SwiftUI app (Home, Generals, Zero Hour, Mods, Settings, Diagnostics), real launch pipeline with
  states, log capture, Stop; bundles as `build/NOVEXA Generals Mac.app` (arm64, ad-hoc signed) with engine embedded.
  App launches, creates Application Support folders and quits cleanly.
* M8 mods (import/enable/disable/remove-with-backup/conflicts) and backups/restore.

## Build / tests
* Engine build: PASS for Zero Hour (`zh`) and Generals (`generals`); both bundled in the app.
* `swift test`: 23/23 PASS.
* Gameplay: NOT TESTED — no game files on this Mac.

## Known issues
* Portability fixed: `stage-engine.sh` bundles libpng, rewrites all `/opt/homebrew` and build-dir references to
  `@rpath`, sets `@executable_path`/`@loader_path` rpaths, re-signs ad-hoc, and fails if any absolute path remains.
  Verified: engine starts with no `DYLD_LIBRARY_PATH`, all non-system libraries load from the runtime folder.
  Not verified on a second Mac without Homebrew; DXVK/MoltenVK loading only happens when a window opens.
* Project path contains a space; builds go through `~/Library/Caches/com.novexa.generalsmac/GeneralsX` symlink.
* First engine compile once failed with a spurious `castres.h not found`; the incremental rebuild passed.

## Blocker
Real gameplay verification needs the user's own Generals / Zero Hour files.
