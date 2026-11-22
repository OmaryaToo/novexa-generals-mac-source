# Graphics

**Pipeline:** engine Direct3D 8 calls → DXVK (native macOS dylib) → Vulkan → MoltenVK → **Metal** → Apple GPU.

* Metal is the GPU API in use, but through translation layers; NOVEXA has not written a Metal renderer.
* Window/fullscreen/Retina handling: SDL3 (DXVK WSI = SDL3). GeneralsX includes a HiDPI WSI fix in its pinned DXVK.
* `dxvk.conf` from GeneralsX is shipped next to the engine when present.
* Shader/pipeline cache: `DXVK_STATE_CACHE_PATH` → `Application Support/.../Cache`.
## Launcher Graphics panel (per game)
Presets Balanced / High (default) / Ultra / Custom. Written before each launch, with a backup on change, into the
engine's user data `~/Library/Application Support/GeneralsX/<Generals|GeneralsZH>/`:
* `Options.ini`: Resolution, `StaticGameLOD = Custom`, AntiAliasing (MSAA 0/2/4/8), TextureFilter = Anisotropic,
  AnisotropyLevel 2–16, TextureReduction 0, FPSLimit, post-processing (FXAA/Bloom/HDR), lighting, shadows,
  explosion lights, headlights, water, heat haze, extra animations, TerrainDrawDistanceScale.
* `SagePatch.ini` `GameData` block: `UseFPSLimit`, `FramesPerSecondLimit` (engine presets 30…480, or uncapped).
  Game logic stays at 30 Hz.
* **Retina:** `-xres/-yres` are physical pixels (engine sets `SDL_WINDOW_HIGH_PIXEL_DENSITY`; the engine `.app`
  has `NSHighResolutionCapable`). Verified: `-xres 2560 -yres 1440 -win` → DXVK buffer 2560×1440 in a 1280×720-pt
  window. Fullscreen default = native panel pixels (3024×1964 on the 14" M5).
* Optional Metal Performance HUD (`MTL_HUD_ENABLED=1`) to show FPS over the game.

## Verified (2026-11-22, M5)
* Main menu and skirmish render in both games (user-confirmed).
* Ultra settings (MSAA 8×, aniso 16×, FXAA+Bloom, 120 FPS cap) at 2880×1620: ran 30 s without errors, buffer
  2880×1620. **FPS not measured numerically** — the HUD draws on screen only; ask the player to read it.

## Roadmap
Evaluate replacing DXVK+MoltenVK with a direct D3D8→Metal layer (dvcdsys/GeneralsGameCode-macOS shows this is feasible).
