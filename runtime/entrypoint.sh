#!/bin/sh
# A thin wrapper around the official docker-entrypoint.sh, which still does all the work
# (initdb, POSTGRES_* handling, the drop from root to postgres, exec of the server).
#
# pg_cron lives in exactly one database per cluster, named by cron.database_name, and
# CREATE EXTENSION pg_cron fails in any other. The setting is fixed at server start, so it
# is passed on the command line here: the official entrypoint hands these arguments to the
# temporary init server as well, which lets the NUQ init script create pg_cron on a fresh
# cluster. A -c flag overrides postgresql.conf and ALTER SYSTEM, so it is only added when
# asked for; otherwise whatever the cluster's own config says (default: postgres) stands.
set -eu

cron_db=${PG_CRON_DATABASE:-${NUQ_DATABASE:-}}
if [ -n "${NUQ_DATABASE:-}" ] && [ "$cron_db" != "$NUQ_DATABASE" ]; then
  echo "NUQ_DATABASE ($NUQ_DATABASE) needs pg_cron in the same database, but PG_CRON_DATABASE is $cron_db" >&2
  exit 1
fi

# Only for the server itself (postgres, or bare flags the official entrypoint prefixes with
# postgres), never for a one-off command such as `docker run ... psql`.
if [ -n "$cron_db" ]; then
  case "${1:-}" in
    postgres|-*) set -- "$@" -c "cron.database_name=$cron_db" ;;
  esac
fi

exec docker-entrypoint.sh "$@"
