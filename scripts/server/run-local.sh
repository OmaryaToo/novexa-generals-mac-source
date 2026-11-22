#!/usr/bin/env bash
# Runs the GeneralsOnline server (Debug build = development login, no web portal needed).
# Usage: run-local.sh [advertise-host]   (default 127.0.0.1; pass your LAN IP for other PCs/Macs)
set -eo pipefail
source "$(dirname "$0")/env.sh"
source "$SECRETS"
HOST="${1:-127.0.0.1}"
"$(dirname "$0")/db.sh" start
# Configuration via environment variables — upstream appsettings.json is never edited.
export Database__db_host=127.0.0.1 Database__db_port=$DB_PORT Database__db_name="$DB_NAME"
export Database__db_username="$DB_USER" Database__db_password="$DB_PASSWORD"
export JwtSettings__Key="$JWT_KEY"
export Core__ws_address="ws://$HOST:9001/ws" Core__ws_address_insecure="ws://$HOST:9001/ws"
# Plain HTTP only for local/LAN play (no certificate needed): both endpoints serve HTTP.
export Kestrel__Endpoints__HTTPS__Url="http://0.0.0.0:9002" Kestrel__Endpoints__HTTP__Url="http://0.0.0.0:9001"
export ASPNETCORE_ENVIRONMENT=Development
cd "$SERVER_SRC/GenOnlineService"
exec dotnet run --no-launch-profile -c Debug
