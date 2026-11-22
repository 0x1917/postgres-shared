#!/usr/bin/env bash
# Smoke test for the __APP__ image: boot it the way the Unraid template does and walk the
# paths Unraid users depend on. Everything runs in one disposable container and a throwaway
# data dir, removed on exit.
#
#   scripts/smoke-test.sh [image]        (default: __APP__:test)
#
# SMOKE_DOCKER_ARGS adds `docker run` arguments, e.g. the template's Extra Parameters.
#
# Requires: docker, curl, bash.
set -euo pipefail

IMAGE=${1:-__APP__:test}
NAME=__APP__-smoke-$$
DATA=$(mktemp -d)
# Extra `docker run` arguments, word-split on purpose.
read -r -a EXTRA <<< "${SMOKE_DOCKER_ARGS:-}"

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  # The entrypoint re-owns /data to 99:100, so a non-root runner cannot unlink it; the
  # image itself (as root) can. Cleanup never decides the verdict.
  docker run --rm --entrypoint rm -v "$DATA:/d" "$IMAGE" -rf /d/data >/dev/null 2>&1 || true
  rm -rf "$DATA" 2>/dev/null || echo "note: left $DATA behind" >&2
}
trap cleanup EXIT
pass() { printf 'PASS  %s\n' "$1"; }
die()  { printf 'FAIL  %s\n' "$1" >&2; docker logs "$NAME" 2>&1 | tail -25 >&2 || true; exit 1; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

mkdir -p "$DATA/data"
docker run -d --name "$NAME" -p 127.0.0.1::__PORT__ "${EXTRA[@]}" \
  -v "$DATA/data:/data" "$IMAGE" >/dev/null
PORT=$(docker port "$NAME" __PORT__/tcp | head -1 | sed 's/.*://')
U="http://127.0.0.1:$PORT"

for _ in $(seq 1 60); do
  [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" = true ] || die "container exited during startup"
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$NAME")" = healthy ] && break
  sleep 2
done
[ "$(docker inspect -f '{{.State.Health.Status}}' "$NAME")" = healthy ] || die "healthcheck never passed"
pass "container is healthy"

# PID 1 is tini; its child is the app, which must have dropped to 99:100.
ids=$(docker exec "$NAME" sh -c 'for s in /proc/[0-9]*/status; do
  [ "$s" = "/proc/$$/status" ] && continue
  awk "/^PPid:/{pp=\$2} /^Uid:/{u=\$2} /^Gid:/{g=\$2} END{if (pp == 1) print u\":\"g}" "$s" 2>/dev/null
done' | sort -u)
[ "$ids" = "99:100" ] || die "the app runs as '$ids', expected 99:100"
pass "the app runs as 99:100"

owner=$(docker exec "$NAME" stat -c '%u:%g' /data)
[ "$owner" = "99:100" ] || die "/data is owned by '$owner'"
pass "/data is owned by 99:100"

[ "$(code "$U/")" != 000 ] || die "nothing answers on port __PORT__"
pass "the app answers HTTP"

# TODO(template): the checks that matter for this app: login, an API call, a static asset,
# anything that has broken before.

# The app must get the stop signal itself and exit on its own, not be killed at the timeout.
start=$(date +%s)
docker stop -t 20 "$NAME" >/dev/null
took=$(( $(date +%s) - start ))
rc=$(docker inspect -f '{{.State.ExitCode}}' "$NAME")
[ "$took" -lt 10 ] && { [ "$rc" = 0 ] || [ "$rc" = 143 ]; } \
  || die "docker stop took ${took}s with exit code $rc (expected a clean exit)"
pass "docker stop: clean exit $rc in ${took}s"

echo "smoke test passed: $IMAGE"
