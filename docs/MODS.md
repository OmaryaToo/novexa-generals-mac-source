# Mods

Implemented: import (.big, .zip, folder), per-game compatibility tag, enable/disable, removal with automatic backup,
per-game active mod selection, conflict detection (same relative file in two enabled mods), backup/restore of the mod index.

Each mod lives in `Mods/<uuid>/content/` and is passed to the engine with `-mod <path>`. Game folders are untouched.

Not tested: Contra, ShockWave, Rise of the Reds or any other real mod — no game data on the build machine.
Large total conversions that ship their own launcher/executable may need a different integration.
