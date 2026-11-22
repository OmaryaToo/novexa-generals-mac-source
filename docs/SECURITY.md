# Security and legal boundaries

## Legal
* Engine code: EA's GPL-3.0 release via GeneralsX (GPL-3.0-or-later). The launcher is distributed
  under the same license (see LICENSE).
* No EA game data, executables, music, video or maps are included, downloaded or redistributed.
  `.gitignore` blocks common game-data extensions.
* No DRM or authentication is bypassed. The engine reads data files the user already owns.
* Not affiliated with or endorsed by Electronic Arts.

* Game artwork shown in the launcher (cover `Install_Final.bmp`, emblem `.ico`) is read at runtime from the
  player's own installation folder and never bundled or redistributed. Without a configured install the UI
  shows Novexa brand artwork only.
* Dock icon while playing: on first Play the launcher copies the engine app to
  `Application Support/.../Engine/personalized/<game>/`, builds `AppIcon.icns` from the `.ico` in the player's own
  install (system `iconutil`), and re-signs the copy ad hoc (system `codesign`). Refreshed only when the engine or
  icon changes; any failure falls back to the stock Novexa-branded engine. No EA art is shipped.
* Bundled fonts: Alexandria, Instrument Sans, IBM Plex Mono — SIL Open Font License (texts in
  `app/Sources/NovexaLauncher/Resources/Fonts/OFL-*.txt`, copied into the app bundle).
* Novexa wordmark/star: from novexa-jo.com (the project owner's brand).

## License compliance (2026-11-22)
* EA's GPL §7 terms: no EA trademarks in the distributed modified program. Engine apps are "NOVEXA ZH" / "NOVEXA Classic",
  window titles and menu credit are neutral, and a non-affiliation disclaimer appears on Home, About and in NOTICE.md.
  Open item: the launcher's own product name still contains "Generals"; owner to decide on a rename before public launch.
* Every bundle ships `Contents/Resources/Legal/`: the GPL+EA terms, NOTICE.md (modifications, dates, source location),
  THIRD_PARTY_NOTICES.md and 29 third-party licenses (`scripts/collect-licenses.sh` fails the build if one is missing).
* GPL §6 corresponding source: public repository https://github.com/OmaryaToo/novexa-generals-mac-source
  (clean export, fresh history; engine via pinned submodule + `engine/patches` applied by `scripts/apply-engine-patches.sh`).
  Re-export it whenever a released build changes (see `scripts/export-public-source.sh`).
* Privacy policy draft: `legal/PRIVACY_POLICY.md` (to publish at novexa-jo.com/privacy and link in the Discord app).

## Launcher behaviour (implemented)
* No telemetry and no updater. The launcher itself makes no network requests; the only download it can
  trigger is the user-initiated Steam download, which runs visibly in Terminal: Valve SteamCMD (official
  HTTPS URL, `curl --proto =https`) and the user's own Steam depots.
* Steam credentials are typed into SteamCMD in Terminal and never pass through the launcher. The account
  name is restricted to `[A-Za-z0-9_]{1,64}` before it is written into the script (no shell injection);
  the script file is mode 0700.
* **Path validation**: `PathSecurity.safeJoin` rejects absolute paths, `..`, backslashes, NULs
  and symlinks resolving outside the target root. Covered by unit tests.
* **Mod import**: only `.big` (magic `BIGF`/`BIG4` checked), `.zip` and folders are accepted.
  Zips are extracted by `/usr/bin/ditto` into an isolated folder and then checked for symlinks that
  escape it. Imported content is never executed by the launcher; it is only passed to the engine
  via `-mod`.
* **Executables**: the launcher only runs the engine binary it locates in its own bundle,
  Application Support, or the dev build folder, and refuses to run it unless its Mach-O header is
  arm64 and its runtime libraries are present. Extra arguments are passed as an argv array (no shell).
* **User data**: game folders are only read. Mod removal and restores create a backup first.
* The app bundle is ad-hoc signed; it is not notarized. Gatekeeper and SIP were not changed.
