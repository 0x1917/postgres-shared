#!/bin/sh
# Exit 0 when the app answers. TODO(template): point this at the app's health endpoint, or
# any URL that answers when it is up.
exec curl -fsS -o /dev/null "http://127.0.0.1:${PORT}/"
