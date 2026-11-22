#!/usr/bin/env bash
# Applies NOVEXA's engine patches (engine/patches/*.patch) to the GeneralsX submodule. Idempotent:
# a patch that is already applied is skipped; one that neither applies nor is applied fails the build.
set -eo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/engine/upstream/GeneralsX"
for p in "$ROOT"/engine/patches/*.patch; do
  if git apply --reverse --check "$p" 2>/dev/null; then echo "already applied: $(basename "$p")"
  elif git apply --check "$p" 2>/dev/null; then git apply "$p"; echo "applied: $(basename "$p")"
  else echo "ERROR: $(basename "$p") does not apply to this engine revision" >&2; exit 1; fi
done
