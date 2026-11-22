# Development environment (recorded 2026-11-22)

Collected with `sw_vers`, `uname -a`, `system_profiler SPHardwareDataType`, `xcodebuild -version`, etc.

| Item | Value |
|---|---|
| Mac | MacBook Pro, Mac17,2 (MDE14LL/A) |
| Chip | Apple M5, arm64 |
| RAM | 16 GB |
| Free disk | ~700 GB of 926 GB |
| macOS | 27.2.1 (build 26B131), Darwin 27.2.0 |
| Xcode | 26.6 (17F113), `/Applications/Xcode.app/Contents/Developer`, macOS SDK 26.5 |
| Swift | 6.3.3 |
| Clang | Apple clang 21.0.0, target arm64-apple-darwin27.2.0 |
| Metal compiler | present (`xcrun -f metal`) |
| Git | 2.50.1 |
| Homebrew | `/opt/homebrew` (arm64) |

## Installed for this project (Homebrew, user-level, no sudo)
cmake 4.5.1, ninja 1.13.2, meson 1.12.1, pkgconf, vcpkg (tool) 2026-10-29, molten-vk 1.4.2,
vulkan-loader 1.4.363, vulkan-headers 1.4.363, glslang 16.6.0, sdl3 3.4.20, libpng 1.6.59.

## Project-local dependencies
* `engine/deps/vcpkg` – clone of microsoft/vcpkg (bootstrapped with `-disableMetrics`).
* `engine/deps/vulkan-sdk/macOS` – a symlink "SDK" layout pointing at the Homebrew
  MoltenVK / Vulkan loader. GeneralsX expects the LunarG SDK layout (`lib/libMoltenVK.dylib`,
  `lib/libvulkan.dylib`, `share/vulkan/icd.d`); this avoids installing the LunarG GUI package.
* `~/Library/Caches/com.novexa.generalsmac/vcpkg` – vcpkg build trees / installed tree. Needed
  because the project folder ("Novexa Launcher") contains a space and vcpkg's FFmpeg port
  refuses to build in paths with spaces.

No game data was found on this Mac (Spotlight search for `INIZH.big` / `INI.big` returned nothing).
