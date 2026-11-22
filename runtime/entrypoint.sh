#!/bin/sh
# Start as root only long enough to match Unraid's ownership, then run the app unprivileged.
set -eu

umask "${UMASK:-022}"

# As root: take on the host's UID/GID (Unraid: 99:100), fix ownership, re-run this script as app.
if [ "$(id -u)" = 0 ]; then
  groupmod -o -g "$PGID" app
  usermod -o -u "$PUID" -g "$PGID" app
  # Only what is wrong is changed, so a large /data restarts fast. A mounted share other
  # than /data is never re-owned: it should already belong to PUID/PGID.
  find /data /home/app \( ! -user app -o ! -group app \) -exec chown -h app:app {} +
  exec gosu app "$0" "$@"
fi

# exec, so the app is tini's direct child: it gets stop signals itself and its exit status
# is the container's.
exec "$@"
