# Build

All commands run from the project root on Apple Silicon. No sudo required.

## 1. Prerequisites
```bash
brew install cmake ninja meson pkgconf vcpkg molten-vk vulkan-loader vulkan-headers glslang libpng
git submodule update --init
git clone https://github.com/microsoft/vcpkg engine/deps/vcpkg
engine/deps/vcpkg/bootstrap-vcpkg.sh -disableMetrics
```
`engine/deps/vulkan-sdk/macOS` is a symlink layout over Homebrew MoltenVK/Vulkan (see ENVIRONMENT.md);
recreate it with the commands in that file if missing.

## 2. Engine (GeneralsX)
```bash
./scripts/build-engine.sh zh         # Zero Hour → GeneralsMD/GeneralsXZH
./scripts/build-engine.sh generals   # Generals  → Generals/GeneralsX
```
`scripts/env.sh` (sourced by every script):
* builds through the symlink `~/Library/Caches/com.novexa.generalsmac/GeneralsX`, because FFmpeg (vcpkg),
  SDL3_image and others fail on paths containing spaces;
* keeps vcpkg build trees/installed packages in `~/Library/Caches/com.novexa.generalsmac/vcpkg`;
* points `VULKAN_SDK` at the local symlink SDK.

First build: vcpkg compiles zlib, freetype, fontconfig, curl, ffmpeg, etc.; DXVK is fetched and built with Meson.
Logs: `build/logs/configure.log`, `build/logs/build_<target>.log`.

## 3. Stage engine & bundle app
```bash
./scripts/stage-engine.sh zeroHour   # → build/runtime.noindex/zeroHour (engine + dylibs + MoltenVK ICD, no game data)
./scripts/bundle-app.sh              # → build/app.noindex/NOVEXA Generals Mac.app (arm64, ad-hoc signed, engines embedded)
```

## 4. Launcher only / tests
```bash
cd app && swift build && swift test
```
