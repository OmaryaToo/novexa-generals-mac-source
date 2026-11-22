# Engine

* Source: `engine/upstream/GeneralsX` (git submodule of fbraz3/GeneralsX, GPL-3.0).
* Targets: `z_generals` → `GeneralsMD/GeneralsXZH` (Zero Hour), `g_generals` → `Generals/GeneralsX`.
* Subsystems (all from the engine, not reimplemented): BIG archive filesystem, INI loader, W3D
  meshes/animation, terrain, particles, game logic, AI, pathfinding, scripting, save/load, replays,
  SDL3 window + keyboard/mouse, MiniAudio sound/music/speech, FFmpeg video, GeneralsOnline networking.
* NOVEXA engine patches (`engine/patches/`, applied in the submodule working tree):
  * `0001-ngmp-runtime-server-selection.patch` — NGMP_SERVER_HOST/PORT/SSL, NGMP_WEB_PORTAL_URL env overrides.
  * `0002-novexa-menu-branding.patch` — main-menu button "NOVEXA", title "NOVEXA OPTIONS", product title "NOVEXA",
    window titles "NOVEXA ZH" / "NOVEXA Classic", and the main-menu credit line
    "NOVEXA · Powered by GeneralsX (GPL-3.0) · Not affiliated with EA · novexa-jo.com".
  The engine remains GeneralsX (GPL-3.0); credits are kept in README/RESEARCH.
  Build-environment adaptations live in `scripts/` (see BUILD.md).

## Runtime contract used by the launcher
| Item | Value |
|---|---|
| Data | `-assetPath <dir>`; Zero Hour also `-generalsAssetPath <dir>` |
| Display | `-win` / `-fullscreen`, `-xres`, `-yres` |
| Mods | `-mod <file.big or dir>` |
| Audio off | `-noaudio` |
| Env | `DYLD_LIBRARY_PATH=<engine dir>`, `VK_ICD_FILENAMES=<engine dir>/MoltenVK_icd.json`, `DXVK_WSI_DRIVER=SDL3`, `FONTCONFIG_FILE` |
