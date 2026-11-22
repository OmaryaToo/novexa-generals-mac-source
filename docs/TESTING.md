# Testing

## Automated (`cd app && swift test`)
30 XCTest cases in `app/Tests/NovexaCoreTests/CoreTests.swift`, last run 2026-11-22 on the M5 MacBook Pro: **30 passed, 0 failed** (updated with Steam-download tests).

Covered: installation detection (not configured / missing / invalid / incomplete / valid, case-insensitive names,
corrupt BIG header, discovery of known locations), path traversal and symlink escape, name sanitising, settings
round-trip and corruption fallback, Mach-O architecture detection, engine component checks, launch-plan arguments
and environment, wrong-arch and incompatible-mod rejection, mod import (.big, folder), rejection of unsupported
files, conflict detection, enable/disable persistence, removal-with-backup, backup + restore (including pre-restore backup).

Fixtures are synthetic files containing only the 4-byte `BIGF` magic — no game data.

## Manual
`tests/manual/FIRST_PLAYABLE.md` — **not run yet**: no game data on the development Mac.

## Engine smoke test (2026-11-22, M5)
`GeneralsXZH -headless -win -assetPath <empty dir>` with the staged runtime: process starts natively (arm64),
initialises LocalFileSystem, BIG ArchiveFileSystem and GlobalData, then exits with status 1:
`[INI] ERROR: No files read from directory 'Data\INI\Default\GameData'` — the expected result without game data.
Window, Vulkan/MoltenVK device creation and rendering were **not** exercised (headless, no data).

## First real launch (2026-11-22, M5, Steam copy downloaded with SteamCMD)
* Engine with `-assetPath ~/Games/ZeroHour -generalsAssetPath ~/Games/ZeroHour/ZH_Generals -win -xres 1600 -yres 900`:
  Vulkan device "Apple M5" via MoltenVK, swapchain created, MiniAudio on MacBook Pro Speakers. Exited cleanly (code 0).
* Launched from the NOVEXA launcher PLAY button: **main menu displayed** (confirmed by the user).
* Not yet verified: skirmish, map load, units, commands, AI, in-game audio, fullscreen.
* Known noise: `[NGMP] Poll HTTP error` repeats — the online service defaults to localhost:9001 in this build.
* Skirmish: **started, map loaded, units move on command** (confirmed by the user, 2026-11-22).
  Still to confirm: AI activity, audio in-game, performance, fullscreen.

## Generals first launch (2026-11-22, M5)
`g_generals` builds as arm64; staged and bundled. Launched with `-assetPath ~/Games/Generals -win`: Vulkan device
Apple M5, swapchain created, MiniAudio on speakers, ran 30 s, exited code 0 on SIGTERM.
Log notes `Could not find shader file: shaders\fterrain.pso / Trees.vso` — these files are not in retail
Generals `shaders.big` (verified by listing the archive); the engine falls back. Main menu and skirmish: **verified working by the user** (2026-11-22).
