#!/usr/bin/env bash
# Exports the committed tree to build/public/novexa-generals-mac as a fresh single-commit repository
# (no private history), keeps submodules as pinned gitlinks, and refuses to finish if the audit finds
# private data. The public remote is preconfigured; publishing is a separate, explicit push.
set -eo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ -z "$(git status --porcelain -- . ':!engine/upstream/GeneralsX')" ]] || { echo "Commit your changes first."; exit 1; }
P="$ROOT/build/public/novexa-generals-mac"
rm -rf "$P"; mkdir -p "$P"
git archive HEAD | tar -x -C "$P"
rm -rf "$P/engine/upstream/GeneralsX" "$P/server/upstream/GeneralsOnlineGameServer"
cd "$P"; git init -q -b main; git add -A
for sm in engine/upstream/GeneralsX server/upstream/GeneralsOnlineGameServer; do
  git update-index --add --cacheinfo 160000,"$(git -C "$ROOT" ls-tree HEAD "$sm" | awk '{print $3}')","$sm"
done
# Audit: private IPs, personal paths/emails, private keys, long hex secrets.
if git grep -nIE "193\.23\.127\.|192\.168\.[0-9]+\.[0-9]+|/Users/[a-z]{2,}/|ommq27|@gmail\.com|BEGIN [A-Z ]*PRIVATE KEY|\b[a-f0-9]{48,}\b" -- . ':!scripts/export-public-source.sh' ; then
  echo "AUDIT FAILED: private data found above. Nothing was exported."; rm -rf "$P"; exit 1
fi
# Deterministic commit (date of the source commit): re-exporting unchanged code gives the same hash,
# so a push is a no-op ("Everything up-to-date") instead of a needless forced update.
export GIT_AUTHOR_DATE="$(git -C "$ROOT" log -1 --format=%cI)" GIT_COMMITTER_DATE="$(git -C "$ROOT" log -1 --format=%cI)"
git -c user.name="NOVEXA" -c user.email="noreply@novexa-jo.com" commit -q -m "NOVEXA Generals Mac — public source ($(git -C "$ROOT" rev-parse --short HEAD))

Native Apple Silicon launcher for C&C Generals / Zero Hour (bring your own game files),
NOVEXA patches to the GeneralsX engine (GPL-3.0 with EA additional terms), build and
packaging scripts, and the NOVEXA Generals Online deployment.

Not affiliated with or endorsed by Electronic Arts Inc."
git remote add origin https://github.com/OmaryaToo/novexa-generals-mac-source.git
echo "Exported $(git ls-files | wc -l | tr -d ' ') files to $P (audit passed)"
echo "Publish with: git -C \"$P\" push --force origin main"
