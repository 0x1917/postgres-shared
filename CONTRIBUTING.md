# Contributing

This repository packages [PostgreSQL](https://github.com/postgres/postgres) with pgvector,
VectorChord, PostGIS and pg_cron into a single container image and publishes it. It holds no
application code: the `Dockerfile`, the `runtime/` scripts it installs, and the CI workflows
are the whole of it.

## Where a report or a change belongs

| Subject                                                                     | Goes to                                                                                                                                                                                                                                                                                                          |
| --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The image: build, entrypoint, extension pins, CI, how the container behaves | Here: [issues](https://github.com/0x1917/postgres-shared/issues) and pull requests                                                                                                                                                                                                                               |
| The Unraid template: fields, defaults, artwork, the Docker tab entry        | [`0x1917/unraid-templates`](https://github.com/0x1917/unraid-templates/issues)                                                                                                                                                                                                                                   |
| PostgreSQL or an extension itself                                           | PostgreSQL: [bug form](https://www.postgresql.org/account/submitbug/); extensions: [pgvector](https://github.com/pgvector/pgvector/issues), [VectorChord](https://github.com/tensorchord/VectorChord/issues), [PostGIS](https://trac.osgeo.org/postgis/), [pg_cron](https://github.com/citusdata/pg_cron/issues) |
| A security vulnerability                                                    | [SECURITY.md](SECURITY.md), privately, not a public issue                                                                                                                                                                                                                                                        |

If you are unsure, open it here and it will be moved rather than closed.

## Run the checks before you open a pull request

CI runs all of these, and a pull request that fails them will not be reviewed until it passes:

```sh
node --test scripts/tags.test.mjs
bash scripts/check-build-inputs.sh
shellcheck -x -S warning runtime/*.sh scripts/*.sh
actionlint .github/workflows/*.yml
docker build -t postgres-shared:test . && bash scripts/smoke-test.sh postgres-shared:test
```

## The invariants the tests enforce

- **The official entrypoint stays in charge.** `runtime/entrypoint.sh` only appends
  `cron.database_name` and execs `docker-entrypoint.sh`, which starts as root, fixes the data
  directory, and drops to `postgres` with `gosu`. No `USER` instruction, no PUID/PGID remap.
- **The server is PID 1.** It receives the official image's stop signal (SIGINT, a fast
  shutdown) itself. The smoke test checks for a clean `docker stop`.
- **Nothing alters a cluster's config.** Extensions are installed, never enabled; no init
  script runs `ALTER SYSTEM`. The smoke test checks `postgresql.auto.conf` stays empty.
- **PostgreSQL stays on major 17.** A major bump breaks every existing data directory, so it
  is a new decision, never a Renovate PR (renovate.json5).
- **Git tags are `v<version>`**, with `v<version>-r<n>` for a rebuild, ordered by semver
  (`scripts/tags.mjs`).

## Changing the image

- Keep the privilege model intact: nothing runs as root after the official entrypoint's setup.
- Comments explain *why* a thing is done, especially where the obvious alternative fails. A
  change that removes one needs to replace it with the reason.
- If you change behaviour a user can see, update [README.md](README.md). If the change affects
  what the image needs at run time, the Unraid template needs a matching change, in the
  templates repository, as a separate pull request.

## Versions, tags, and releases

Do not bump `UPSTREAM_VERSION`, create a git tag, or edit the publish workflow's release logic
in a pull request: Renovate proposes PostgreSQL and extension bumps and the maintainer cuts
releases. A VectorChord bump also needs its `VCHORD_SHA256`, from the release asset.

## Pull request shape

- One concern per pull request. A formatting sweep mixed with a fix will be asked to split.
- Say why in the description, not just what. The diff already says what.
- Do not reorder `Dockerfile` layers for tidiness; the order is the cache.
- Do not reformat files you did not otherwise touch.

## Licensing

This repository is [MIT](LICENSE). There is no CLA and no contributor agreement: by opening a
pull request you agree your contribution is licensed under the same terms. PostgreSQL and each
bundled extension carry their own licenses; see the README.
