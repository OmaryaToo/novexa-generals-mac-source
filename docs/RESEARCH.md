# Engine research

## Legal basis
On 2025-02-27 Electronic Arts published the source of *C&C Generals* and *Zero Hour*
(`electronicarts/CnC_Generals_Zero_Hour`) under **GPL-3.0** with additional terms. The code
is usable; the **game data (art, audio, maps, INI archives) is not** and must come from the
user's own purchased copy.

## Candidates inspected (2026-11-22)

| Project | Activity | License | Platforms / approach | Games | Verdict |
|---|---|---|---|---|---|
| electronicarts/CnC_Generals_Zero_Hour | archive, last push 2025-02 | GPL-3.0 + EA terms | Win32, VC6, DirectX 8 | both | Reference only; does not build on macOS |
| TheSuperHackers/GeneralsGameCode | very active (pushed 2026-11-21), 1.5k★ | GPL-3.0 | Windows-focused modernization, fixes, VS2022/CMake | both | Upstream of most forks; no macOS renderer |
| **fbraz3/GeneralsX** | very active (pushed 2026-11-21), 413★, CI | GPL-3.0 | macOS arm64 / Linux / Windows; SDL3 windowing+input, DXVK (D3D8/9→Vulkan) + MoltenVK (Vulkan→Metal), MiniAudio, FFmpeg video | **both** | **Chosen** |
| dvcdsys/GeneralsGameCode-macOS | 20 commits, last 2026-07-18, 4★ | GPL-3.0 | In-tree D3D8→Metal shim, no DXVK | Zero Hour only | Strong alternative for a pure-Metal path; single maintainer, no Generals, no networking |
| ammaarreshi/Generals-Mac-iOS-iPad | last 2026-07-05, 1.7k★ | GPL-3.0 | Derived from GeneralsX, DXVK/MoltenVK, adds iOS/iPad | ZH | Downstream of GeneralsX; nothing extra needed for Mac |
| TheodoryLabs …-web | WebAssembly/WebGL | GPL-3.0 | Browser | ZH | Not relevant |
| chayuto/generals-rust | logic-only Rust port | – | Deterministic logic engine | – | Not a full engine |

### What GeneralsX actually is (verified by reading the source)
* Real C++ engine compiled from the EA source (`Core/`, `Generals/`, `GeneralsMD/`), CMake preset
  `macos-vulkan`: `CMAKE_OSX_ARCHITECTURES=arm64`, `SAGE_USE_DX8=OFF`, `SAGE_USE_SDL3=ON`,
  `SAGE_USE_MINIAUDIO=ON`, `SAGE_USE_MOLTENVK=ON`.
* No Wine, no Rosetta, no Windows executables. Output is a native Mach-O arm64 binary.
* Rendering: the engine still issues Direct3D 8 calls; these go to DXVK built natively for macOS
  (`libdxvk_d3d8/d3d9.dylib`), which emits Vulkan, which MoltenVK translates to Metal. Metal is
  the GPU API that ultimately runs, but via two translation layers — it is **not** a hand-written
  Metal renderer.
* Data paths: `-assetPath`, `-generalsAssetPath`, env `CNC_GENERALS_ZH_PATH` / `CNC_GENERALS_PATH`.
* Mods: `-mod <file.big|dir>`.

## Decision
Use **GeneralsX** as the engine foundation (git submodule at `engine/upstream/GeneralsX`,
upstream history preserved). Reasons: both games, active maintenance and CI on macOS arm64,
existing audio/video/input/networking, and it is the base that other Mac ports build on.
NOVEXA contributes the native launcher, installation/mod/backup management and a reproducible
build that does not require the LunarG SDK installer.

The dvcdsys direct-Metal shim is recorded as the most promising route to a renderer without
DXVK/MoltenVK (see ROADMAP.md).
