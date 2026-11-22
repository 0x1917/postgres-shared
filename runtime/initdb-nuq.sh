#!/usr/bin/env bash
# Run by the official entrypoint on a FRESH data directory only (it skips
# /docker-entrypoint-initdb.d when PGDATA already holds a cluster). With NUQ_DATABASE set,
# it creates that database if needed and loads firecrawl's NUQ queue schema into it;
# without it, it does nothing. Executable on purpose: the entrypoint sources a .sh that
# is not, and an `exit 0` would then end the entrypoint itself.
set -euo pipefail

[ -n "${NUQ_DATABASE:-}" ] || exit 0

psql=(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --no-password --no-psqlrc)

if [ "$("${psql[@]}" -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname = '${NUQ_DATABASE//\'/\'\'}'")" != 1 ]; then
  "${psql[@]}" -d postgres -v db="$NUQ_DATABASE" <<< 'CREATE DATABASE :"db";'
fi
"${psql[@]}" -d "$NUQ_DATABASE" -f /usr/local/share/postgres-shared/nuq.sql
echo "loaded the NUQ queue schema into $NUQ_DATABASE"
