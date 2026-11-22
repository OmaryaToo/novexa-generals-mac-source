# Architecture

```
NOVEXA Generals Mac.app  (Swift / SwiftUI, arm64)
 ├─ NovexaLauncher   UI: Home, Generals, Zero Hour, Mods, Settings, Diagnostics
 └─ NovexaCore       InstallationValidator · EngineLocator/MachO · LaunchPlanner ·
                     GameProcessRunner · ModManager · BackupManager · PathSecurity ·
                     SettingsStore · AppPaths · Diagnostics
        │  Process(argv, env)  -assetPath <user data> [-generalsAssetPath] [-mod] -win|-fullscreen -xres -yres
        ▼
Contents/Resources/Engine/<game>/<Name>.app   (GeneralsX, native arm64 Mach-O)
   Name = "NOVEXA ZH" | "NOVEXA Classic" (no EA trademarks) — own Info.plist + icon + Resources/Legal
   Contents/MacOS: GeneralsXZH | GeneralsX + dylibs; Contents/Resources: MoltenVK_icd.json, dxvk.conf, fontconfig
   libSDL3 (window, input) · libdxvk_d3d8/d3d9 (D3D8→Vulkan) · libMoltenVK (Vulkan→Metal)
   libvulkan loader · MiniAudio (static) · FFmpeg (static, video)
        ▼
User's own game folder (read-only): *.big archives
```

The launcher and engine are separate processes. The launcher stays responsive, records engine
stdout/stderr to a per-launch log and returns to Idle on exit (or Failed with the exit status).

## Storage (`~/Library/Application Support/NOVEXA Generals Mac/`)
`settings.json`, `Engine/<game>/` (optional engine override), `GameConfigs/<game>/`, `Mods/<uuid>/content`,
`Mods/mods.json`, `Logs/`, `Backups/*.zip`, `Cache/` (DXVK state cache).

## Launch states
Idle → Preparing (validation, plan) → Loading (process spawn) → Running(pid) → Exiting (SIGTERM, SIGKILL after 5 s) → Idle.
Any validation or spawn error, or a non-zero exit, → Failed(message).

## Design system
Tokens mirror novexa-jo.com (dark variant) in `app/Sources/NovexaLauncher/Theme.swift`: ink `#0B0A14`,
line `#25213A`, edge `#3A3550`, text `#ECEAF5`, mute `#ABA7C0`, brand gradient `#7C3AED → #EC4899 → #FB923C`,
radii 8/14/22, Alexandria (display) / Instrument Sans (body) / IBM Plex Mono (eyebrows, data).
`Brand.swift` redraws the Novexa wordmark and star as native paths. `GameArt.swift` loads and crops official art
from the user's install.

Developer aid: `NOVEXA_SECTION="Zero Hour" NOVEXA_SNAPSHOT=/tmp/x.png "<app>/Contents/MacOS/NOVEXA Generals Mac"`
renders the window to PNG and quits (no Screen Recording permission needed).
