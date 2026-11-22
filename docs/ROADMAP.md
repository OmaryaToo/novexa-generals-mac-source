# Roadmap

1. First launch with real game data (needs user files): reach the main menu, then skirmish.
2. Record verified features in TESTING.md (map load, units, commands, AI, audio, exit).
3. Bundle Generals (`g_generals`) as well as Zero Hour.
4. Display: borderless, display selection, VSync/FPS cap toggles mapped to engine/DXVK options.
5. Per-game config isolation: point the engine's user-data dir into `GameConfigs/<game>` and back it up.
6. Notarized, signed release DMG.
7. Investigate a direct D3D8→Metal backend to remove DXVK + MoltenVK.
