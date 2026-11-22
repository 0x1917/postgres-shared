# Security policy

This repository packages [PostgreSQL](https://www.postgresql.org/) and four extensions into one container
image. It is a build and packaging repository, not a fork of the application. That split
decides where a report belongs, so read the first section before opening anything.

## Where to report

| Subject                                         | Report it at                                                                             |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------- |
| This image: `Dockerfile`, `runtime/`, workflows | [Private report here](https://github.com/0x1917/postgres-shared/security/advisories/new) |
| Upstream app                                    | Upstream's own security policy; if it has none, report it here privately                 |

If you are unsure which side a bug sits on, report it here and it will be forwarded. A report
sent to the wrong place is fine, a report never sent is not.

Private vulnerability reporting opens an advisory thread visible only to you and the
maintainer, and that thread becomes the place the fix is discussed and published. Please do
not open a public issue with a working exploit that other people's instances are vulnerable
to. Everything else is fine as a normal issue: a crash you can only trigger on your own box,
a scanner warning, a misconfiguration in the example commands.

## Supported versions

Only the **newest published image tag**. Image tags are the upstream release number
(`1.2.3`, `latest`), with `-r<n>` for a rebuild of the same release; a fix ships as a new
tag, and older tags are never patched.

```sh
docker pull 0x1917/postgres-shared:latest
```

## What the image does and does not protect

- **The container starts as root** only for the official entrypoint to fix ownership of the
  data directory; it then drops to `postgres` (uid 999) with `gosu`. The server is unprivileged.
- **The network is yours to restrict.** The official image's `pg_hba.conf` accepts password
  logins from any address. Do not forward port 5432 to the internet; give each app its own
  role with access to its own database only.
- **Extension superuser code.** pg_cron jobs run as the role that scheduled them, and
  `CREATE EXTENSION` for these extensions needs a superuser. Neither is reachable by a
  database owner who is not one.
- The image ships no secrets. `POSTGRES_PASSWORD` arrives at run time and only applies when
  a new cluster is initialised.

Dependency updates and base-image CVEs with no reachable exploit path are Renovate's job
here; a report is more useful when it says how an attacker reaches the code.

## What to include

- The image tag and, if you have it, the digest.
- How you run it: `docker run`, a compose file, Unraid, or behind a reverse proxy.
- Steps to reproduce, with the request or command that triggers it.
- What an attacker gets: data, another user's session, denial of service, nothing.
