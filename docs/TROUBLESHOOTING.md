# Troubleshooting

| Symptom | Cause / fix |
|---|---|
| vcpkg: "ffmpeg will not build with spaces in the path" | Project path has a space. `scripts/env.sh` builds through `~/Library/Caches/com.novexa.generalsmac/GeneralsX` (symlink) and keeps vcpkg trees there. |
| `clang: no such file … Launcher/engine/…SDL_image.exports` | Same cause (unquoted path in SDL3_image). Same fix. |
| `libpng not found` at configure | `brew install libpng` |
| `Vulkan SDK not found` | Not needed: `engine/deps/vulkan-sdk/macOS` symlinks Homebrew's MoltenVK. Re-run `brew install molten-vk vulkan-loader`. |
| PLAY says "engine not installed" | Run `scripts/stage-engine.sh zeroHour` then `scripts/bundle-app.sh`. |
| Black window / lost mouse | Use Windowed and a preset resolution; check the launch log in Diagnostics. |
| App "damaged" on another Mac | Ad-hoc signed, not notarized. |
