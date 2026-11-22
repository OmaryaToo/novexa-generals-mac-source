#!/usr/bin/env bash
# Shared settings for the local GeneralsOnline server (development / LAN use).
SRV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SERVER_SRC="$SRV_ROOT/server/upstream/GeneralsOnlineGameServer"
export SERVER_DATA="$HOME/Library/NovexaGeneralsServer"      # no spaces: MariaDB tools dislike them
export DB_PORT=3307                                           # separate from any system MySQL on 3306
export DB_SOCKET="$SERVER_DATA/mysql.sock"
export DOTNET_ROOT=/opt/homebrew/opt/dotnet@10/libexec
export PATH="/opt/homebrew/opt/dotnet@10/bin:/opt/homebrew/bin:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
SECRETS="$SERVER_DATA/secrets.env"
