#!/usr/bin/env bash
# Smoke test for the postgres-shared image: boot it the way the Unraid template does and walk
# the paths Unraid users depend on. Two disposable containers on throwaway data dirs, removed
# on exit: a fresh cluster with the defaults, and one with the NUQ schema switched on.
#
#   scripts/smoke-test.sh [image]        (default: postgres-shared:test)
#
# SMOKE_DOCKER_ARGS adds `docker run` arguments, e.g. the template's Extra Parameters.
#
# Requires: docker, bash.
set -euo pipefail

IMAGE=${1:-postgres-shared:test}
NAME=postgres-shared-smoke-$$
DATA=$(mktemp -d)
# Extra `docker run` arguments, word-split on purpose.
read -r -a EXTRA <<< "${SMOKE_DOCKER_ARGS:-}"
CURRENT=

cleanup() {
  docker rm -f "$NAME-plain" "$NAME-nuq" >/dev/null 2>&1 || true
  # The entrypoint re-owns the data dirs to 999 with mode 700, so a non-root runner cannot
  # unlink them; the image itself (as root) can. Cleanup never decides the verdict.
  docker run --rm --entrypoint rm -v "$DATA:/d" "$IMAGE" -rf /d/plain /d/nuq >/dev/null 2>&1 || true
  rm -rf "$DATA" 2>/dev/null || echo "note: left $DATA behind" >&2
}
trap cleanup EXIT
pass() { printf 'PASS  %s\n' "$1"; }
die()  { printf 'FAIL  %s\n' "$1" >&2; [ -z "$CURRENT" ] || docker logs "$CURRENT" 2>&1 | tail -25 >&2 || true; exit 1; }
sql()  { docker exec "$CURRENT" psql -v ON_ERROR_STOP=1 -U postgres -Atq -d "$1" -c "$2"; }

# start <suffix> [docker run args...]: run a fresh cluster and wait for the healthcheck.
start() {
  local suffix=$1; shift
  CURRENT="$NAME-$suffix"
  mkdir -p "$DATA/$suffix"
  docker run -d --name "$CURRENT" -e POSTGRES_PASSWORD=smoke "$@" "${EXTRA[@]}" \
    -v "$DATA/$suffix:/var/lib/postgresql/data" "$IMAGE" >/dev/null
  for _ in $(seq 1 60); do
    [ "$(docker inspect -f '{{.State.Running}}' "$CURRENT")" = true ] || die "$suffix: container exited during startup"
    [ "$(docker inspect -f '{{.State.Health.Status}}' "$CURRENT")" = healthy ] && break
    sleep 2
  done
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$CURRENT")" = healthy ] || die "$suffix: healthcheck never passed"
  pass "$suffix: fresh cluster initialised and healthy"
}

# --- defaults: what a new Unraid install gets ------------------------------------------
start plain

# PID 1 is the postmaster itself (the official image's model), running as postgres.
ids=$(docker exec "$CURRENT" awk '/^Uid:/{u=$2} /^Gid:/{g=$2} END{print u":"g}' /proc/1/status)
[ "$ids" = "999:999" ] || die "the server runs as '$ids', expected 999:999 (postgres)"
pass "the server runs as postgres (999:999)"

# The official entrypoint chowns the data dir to the postgres user only; the group is
# whatever the bind mount brought, and mode 700 makes it irrelevant.
owner=$(docker exec "$CURRENT" stat -c '%u %a' /var/lib/postgresql/data)
[ "$owner" = "999 700" ] || die "the data dir is '$owner' (uid, mode), expected '999 700'"
pass "the data dir is owned by postgres"

[ "$(sql postgres 'SHOW shared_preload_libraries')" = "vchord.so,pg_cron" ] || die "vchord and pg_cron are not preloaded"
pass "vchord and pg_cron are preloaded"

[ "$(sql postgres "SELECT count(*) FROM pg_namespace WHERE nspname = 'nuq'")" = 0 ] || die "NUQ was loaded without NUQ_DATABASE"
pass "NUQ stays off by default"

# Each app's extensions, in a database of its own, the way the README sets them up.
sql postgres 'CREATE DATABASE immich' && sql postgres 'CREATE DATABASE dawarich'
sql immich 'CREATE EXTENSION vchord CASCADE' || die "CREATE EXTENSION vchord failed"
sql immich "CREATE TABLE t (id int, v vector(3)); INSERT INTO t SELECT i, ARRAY[random(), random(), random()]::vector FROM generate_series(1, 500) i; CREATE INDEX ON t USING vchordrq (v vector_l2_ops)" \
  || die "a vchordrq index could not be built"
[ "$(sql immich "SET enable_seqscan = off; SELECT count(*) FROM (SELECT id FROM t ORDER BY v <-> '[0.5,0.5,0.5]' LIMIT 5) s")" = 5 ] \
  || die "a vchordrq nearest-neighbour query returned the wrong row count"
pass "vector + vchord: index built and queried"

sql dawarich 'CREATE EXTENSION postgis' || die "CREATE EXTENSION postgis failed"
d=$(sql dawarich "SELECT round(ST_DistanceSphere('POINT(0 0)'::geometry, 'POINT(0 1)'::geometry))")
[ "$d" = 111195 ] || die "PostGIS returned '$d' m for one degree of latitude"
pass "postgis: geometry functions answer"

sql postgres 'CREATE EXTENSION pg_cron' || die "CREATE EXTENSION pg_cron failed in the default cron database"
pass "pg_cron: installs in its default database (postgres)"

# The server must get the stop signal itself and shut down fast, not be killed at the timeout.
start=$(date +%s)
docker stop -t 20 "$CURRENT" >/dev/null
took=$(( $(date +%s) - start ))
rc=$(docker inspect -f '{{.State.ExitCode}}' "$CURRENT")
[ "$took" -lt 10 ] && [ "$rc" = 0 ] || die "docker stop took ${took}s with exit code $rc (expected a clean exit)"
pass "docker stop: clean exit $rc in ${took}s"

# The same data dir must come back with its data: init scripts never run twice.
docker start "$CURRENT" >/dev/null
for _ in $(seq 1 30); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$CURRENT")" = healthy ] && break
  sleep 2
done
[ "$(sql immich 'SELECT count(*) FROM t')" = 500 ] || die "the data did not survive a restart"
pass "restart: existing cluster reused, data intact"
docker rm -f "$CURRENT" >/dev/null

# --- NUQ on: firecrawl's queue schema and its cron jobs ---------------------------------
start nuq -e NUQ_DATABASE=firecrawl

[ "$(sql postgres 'SHOW cron.database_name')" = firecrawl ] || die "cron.database_name does not follow NUQ_DATABASE"
[ "$(sql firecrawl "SELECT count(*) FROM pg_tables WHERE schemaname = 'nuq' AND tablename = 'queue_scrape'")" = 1 ] \
  || die "the NUQ schema is missing from firecrawl"
jobs=$(sql firecrawl "SELECT count(*) FROM cron.job WHERE jobname LIKE 'nuq_%' AND database = 'firecrawl'")
[ "$jobs" -gt 0 ] || die "no NUQ cron jobs were scheduled"
pass "nuq: schema loaded into firecrawl, $jobs cron jobs scheduled"

[ "$(sql postgres "SELECT count(*) FROM pg_namespace WHERE nspname = 'nuq'")" = 0 ] || die "NUQ leaked into POSTGRES_DB"
# The tuning block upstream ships must stay stripped: nothing may land in postgresql.auto.conf.
auto=$(docker exec "$CURRENT" grep -cvE '^#' /var/lib/postgresql/data/postgresql.auto.conf || true)
[ "$auto" = 0 ] || die "postgresql.auto.conf has $auto settings; the shared cluster's config was changed"
pass "nuq: no ALTER SYSTEM, cluster config untouched"

# The wrapper must refuse a pg_cron database that cannot hold the NUQ jobs.
if docker run --rm -e POSTGRES_PASSWORD=x -e NUQ_DATABASE=a -e PG_CRON_DATABASE=b "$IMAGE" >/dev/null 2>&1; then
  die "NUQ_DATABASE and PG_CRON_DATABASE disagreed and the container started anyway"
fi
pass "entrypoint refuses NUQ_DATABASE != PG_CRON_DATABASE"

echo "smoke test passed: $IMAGE"
