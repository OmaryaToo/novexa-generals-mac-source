# Installing game data

You need your own copy of *Generals* and/or *Zero Hour* (Steam "Ultimate Collection", EA App, The First Decade, or retail discs).
The Windows installers can be run on any Windows PC or via CrossOver/Wine just to obtain the files; copy the
installation folders (the ones that contain `*.big` files) to your Mac.

## Option A — Download from Steam inside the launcher (recommended)
1. Home → **Download from Steam…**, enter your Steam *account name*, choose Zero Hour and/or Generals.
2. A Terminal window opens running Valve's official SteamCMD (installed from Homebrew if present, otherwise
   downloaded from Valve's CDN into `Application Support/.../Tools/steamcmd`). Type your password and Steam
   Guard code **there**; the launcher never sees them.
3. Files go to `~/Games/ZeroHour` (includes `ZH_Generals`) and `~/Games/Generals`. The launcher checks every 5 s
   and when you return to it, and links each folder once all its archives validate.
   Steam app IDs: Generals 2229870, Zero Hour 2732960.

## Option B — existing folders
In the launcher:
1. **Home → Auto-detect** checks known locations (`~/GeneralsX/…`, `~/Games/…`, Steam and CrossOver bottle paths).
2. Or press **Locate…** / drag the folder onto a game card.
3. The validator checks required archives (case-insensitive) and their `BIGF/BIG4` headers:
   * Generals: `INI.big`, `Textures.big`, `W3D.big`, `Window.big`
   * Zero Hour: `INIZH.big`, `TexturesZH.big`, `W3DZH.big`, `WindowZH.big`
   Missing maps/audio/language archives are reported as warnings.
4. For Zero Hour, also set the Generals folder; it is passed as `-generalsAssetPath`.

The launcher never writes to these folders.
