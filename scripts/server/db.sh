#!/usr/bin/env bash
# start | stop | status for the private MariaDB instance (127.0.0.1:3307 only).
source "$(dirname "$0")/env.sh"
case "${1:-status}" in
  start)
    if mariadb-admin --socket="$DB_SOCKET" -u "$(whoami)" ping >/dev/null 2>&1; then echo "db already running"; exit 0; fi
    mariadbd --datadir="$SERVER_DATA/mysql" --port=$DB_PORT --bind-address=127.0.0.1 --socket="$DB_SOCKET" \
      --pid-file="$SERVER_DATA/mysql.pid" --log-error="$SERVER_DATA/mysql.err" >/dev/null 2>&1 &
    for i in $(seq 1 30); do mariadb-admin --socket="$DB_SOCKET" -u "$(whoami)" ping >/dev/null 2>&1 && { echo "db started"; exit 0; }; sleep 0.5; done
    echo "db failed to start; see $SERVER_DATA/mysql.err"; exit 1 ;;
  stop) mariadb-admin --socket="$DB_SOCKET" -u "$(whoami)" shutdown && echo "db stopped" ;;
  status) mariadb-admin --socket="$DB_SOCKET" -u "$(whoami)" ping 2>&1 ;;
esac
