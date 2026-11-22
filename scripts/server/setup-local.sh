#!/usr/bin/env bash
# One-time setup: private MariaDB instance + schema + random secrets. Re-running is safe.
set -eo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$SERVER_DATA"; chmod 700 "$SERVER_DATA"
if [[ ! -f "$SECRETS" ]]; then
  umask 077
  cat > "$SECRETS" <<S
DB_NAME=generalsonline
DB_USER=genonline
DB_PASSWORD=$(openssl rand -hex 24)
JWT_KEY=$(openssl rand -hex 32)
S
fi
source "$SECRETS"
if [[ ! -d "$SERVER_DATA/mysql/mysql" ]]; then
  mariadb-install-db --datadir="$SERVER_DATA/mysql" --auth-root-authentication-method=socket --skip-test-db >/dev/null
fi
"$(dirname "$0")/db.sh" start
mariadb --socket="$DB_SOCKET" -u "$(whoami)" <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
mariadb --socket="$DB_SOCKET" -u "$(whoami)" "$DB_NAME" < "$SERVER_SRC/GenOnlineService/Database_Structure/structure.sql"
echo "Tables: $(mariadb --socket="$DB_SOCKET" -u "$(whoami)" -N -e "select count(*) from information_schema.tables where table_schema='$DB_NAME'")"
echo "Local GeneralsOnline database ready in $SERVER_DATA"
