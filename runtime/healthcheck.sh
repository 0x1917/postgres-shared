#!/bin/sh
# Exit 0 when the server accepts connections over TCP. The official entrypoint's temporary
# init server listens on the Unix socket only, so checking TCP keeps the container
# "starting" until initdb and the init scripts are done and the real server is up.
exec pg_isready -q -h 127.0.0.1 -p "${PGPORT:-5432}" -U "${POSTGRES_USER:-postgres}"
