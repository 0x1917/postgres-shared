# PostgreSQL Shared

[![Version](https://img.shields.io/docker/v/0x1917/postgres-shared)](https://hub.docker.com/r/0x1917/postgres-shared)
[![Build](https://github.com/0x1917/postgres-shared/actions/workflows/build.yml/badge.svg)](https://github.com/0x1917/postgres-shared/actions/workflows/build.yml)
[![Lint](https://github.com/0x1917/postgres-shared/actions/workflows/lint.yml/badge.svg)](https://github.com/0x1917/postgres-shared/actions/workflows/lint.yml)
[![Pulls](https://img.shields.io/docker/pulls/0x1917/postgres-shared)](https://hub.docker.com/r/0x1917/postgres-shared)
[![Image size](https://img.shields.io/docker/image-size/0x1917/postgres-shared)](https://hub.docker.com/r/0x1917/postgres-shared)
[![Platform](https://img.shields.io/badge/platform-linux%2Famd64-blue?logo=linux&logoColor=white)](#run)
[![License](https://img.shields.io/github/license/0x1917/postgres-shared)](https://github.com/0x1917/postgres-shared/blob/master/LICENSE)

PostgreSQL 17 with **pgvector**, **VectorChord**, **PostGIS** and **pg_cron** preinstalled, on
the official `postgres` image and its entrypoint. One database server for every app on
your Unraid box, including apps whose extension needs would otherwise each demand a
dedicated database container. Install it from the Community Applications plugin, or manually
with the template from
[0x1917/unraid-templates](https://github.com/0x1917/unraid-templates/blob/master/templates/my-postgres-shared.xml)
(copy it to `/boot/config/plugins/dockerMan/templates-user/`).

## Why this one

Community Applications already lists plenty of Postgres images. Almost all of them serve one
app or one extension:

| Image kind                                       | pgvector | VectorChord | PostGIS | pg_cron | Fits                     |
| ------------------------------------------------ | -------- | ----------- | ------- | ------- | ------------------------ |
| Official `postgres` / plain PostgreSQL templates | no       | no          | no      | no      | general apps             |
| Immich database images (VectorChord builds)      | yes      | yes         | no      | no      | Immich only              |
| Older Immich images still on pgvecto.rs          | varies   | no          | no      | no      | Immich 2.x and earlier   |
| `postgis/postgis`                                | no       | no          | yes     | no      | Dawarich, GIS apps       |
| `pgvector/pgvector`                              | yes      | no          | no      | no      | RAG / embedding apps     |
| **PostgreSQL Shared** (this image)               | yes      | yes         | yes     | yes     | all of the above at once |

What sets it apart:

- **One cluster instead of one per app.** Immich (vchord + vector), Dawarich (postgis),
  firecrawl (pg_cron + its NUQ queue), Paperless-ngx, Linkwarden and any pgvector RAG app can
  share one server, one appdata folder, one backup job, and one set of tuned memory settings.
  Each app gets its own database and role, so they stay isolated from each other.
- **Drop-in for the official image.** The official `docker-entrypoint.sh` runs unchanged:
  every `POSTGRES_*` variable, `/docker-entrypoint-initdb.d`, `PGDATA`, the `postgres` user,
  and the fast-shutdown stop signal behave exactly as documented on Docker Hub. A data
  directory from `postgres:17` moves over as-is (see [Moving an existing cluster](#moving-an-existing-cluster)).
- **Nothing changes your cluster behind your back.** Extensions are installed, not enabled:
  each one is inert until `CREATE EXTENSION` in a database. No init script runs `ALTER SYSTEM`;
  the optional NUQ schema ships with upstream's cluster-wide tuning block removed.
- **Pinned and verified.** Base image by tag and digest, every extension by exact version.
  apt checks the packages against pgdg's signed index; the VectorChord `.deb` is checked
  against its sha256. Renovate proposes each bump, and every bump passes a smoke test that
  builds a vchord index, runs a PostGIS query and schedules pg_cron jobs before it publishes.
- **Never jumps a major version.** Tags follow the PostgreSQL release (`17.11`, `17.11-r1`
  for a rebuild), and `latest` stays on PostgreSQL 17, so the Update button cannot hand an
  existing cluster a server that refuses to start on it.

Pick a single-purpose image instead if you run exactly one database app and want its
vendor's image, or if you need arm64 (this image is built and tested for amd64 only).

## What is inside

| Component   | Version | Extension name | Preloaded | Typical user                     |
| ----------- | ------- | -------------- | --------- | -------------------------------- |
| PostgreSQL  | 17.11   |                |           |                                  |
| pgvector    | 0.8.6   | `vector`       | no        | Immich, RAG and embedding apps   |
| VectorChord | 0.4.3   | `vchord`       | yes       | Immich (smart search, faces)     |
| PostGIS     | 3.6.4   | `postgis`      | no        | Dawarich, geospatial apps        |
| pg_cron     | 1.6.8   | `pg_cron`      | yes       | firecrawl's NUQ queue, your jobs |

The [Dockerfile](Dockerfile) is the source of truth for the exact pins; the table is what the
first release ships. `shared_preload_libraries = 'vchord.so,pg_cron'` is written into each
**new** cluster's `postgresql.conf`.

## Run

```sh
docker run -d                                       \
  --name postgres-shared                            \
  --restart unless-stopped                          \
  --shm-size 1g                                     \
  -p 5432:5432                                      \
  -e POSTGRES_PASSWORD=change-me                    \
  -v /mnt/user/appdata/postgres-shared:/var/lib/postgresql/data \
  0x1917/postgres-shared
```

`--shm-size` matters: Docker's 64 MB default is too small for parallel queries and index builds.

## Environment

All of the [official image's variables](https://hub.docker.com/_/postgres) work unchanged
(`POSTGRES_PASSWORD`, `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_INITDB_ARGS`, `PGDATA`, ...). This
image adds two:

| Variable           | Default                  | Meaning                                                                                                                                  |
| ------------------ | ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `NUQ_DATABASE`     | empty (off)              | On a fresh data directory, create this database and load firecrawl's NUQ queue schema and cron jobs into it. Implies `PG_CRON_DATABASE`. |
| `PG_CRON_DATABASE` | the cluster's own config | The one database pg_cron lives in (`cron.database_name`). Unset, `postgresql.conf` / `ALTER SYSTEM` decide, default `postgres`.          |

The server runs as the image's `postgres` user (uid 999), like the official image; it does not
use Unraid's `PUID`/`PGID`. The entrypoint re-owns the data directory to 999 with mode 700 on
start, so leave the appdata folder out of "Docker Safe New Perms"-style permission fixes.

## Setting up an app

Connect as the superuser (Unraid: the container's console, `psql -U postgres`) and give each app
its own role and database. Create the extensions as superuser: most apps cannot.

```sql
-- Immich (needs vchord, which pulls in vector)
CREATE ROLE immich LOGIN PASSWORD '...';
CREATE DATABASE immich OWNER immich;
\c immich
CREATE EXTENSION vchord CASCADE;
CREATE EXTENSION earthdistance CASCADE;

-- Dawarich
CREATE ROLE dawarich LOGIN PASSWORD '...';
CREATE DATABASE dawarich OWNER dawarich;
\c dawarich
CREATE EXTENSION postgis;

-- Paperless-ngx, Linkwarden, ...: a role and a database, no extensions
CREATE ROLE paperless LOGIN PASSWORD '...';
CREATE DATABASE paperless OWNER paperless;
```

Point each app at `<unraid-ip>:5432`, its database and its role. For firecrawl, start a **fresh**
cluster with `NUQ_DATABASE=firecrawl`, or load [`runtime/nuq.sql`](runtime/nuq.sql) into an
existing one by hand (it needs `cron.database_name = 'firecrawl'` first).

pg_cron can only be created in one database per cluster, but it can run jobs anywhere:
`SELECT cron.schedule_in_database('nightly-vacuum', '0 3 * * *', 'VACUUM ANALYZE', 'immich');`

## Moving an existing cluster

- **From `postgres:17`:** point this image at the same data directory, then add the preload
  line, which only new clusters get automatically, and restart:
  `ALTER SYSTEM SET shared_preload_libraries = 'vchord.so,pg_cron';`
- **From the Immich, PostGIS or pgvector images:** `pg_dumpall` the old one and restore into
  this one, unless the old image is also PostgreSQL 17 on Debian, in which case the data
  directory can be reused as above. Coming from pgvecto.rs, follow
  [Immich's migration guide](https://docs.immich.app/administration/postgres-standalone/) first.
- **From a different PostgreSQL major:** dump and restore (or `pg_upgrade`). A data directory
  from another major will not start.

## Upgrading

- **PostgreSQL 17 minors and `-r<n>` rebuilds:** pull and restart. Binary-compatible.
- **VectorChord:** upgrades in place along its release chain. After a new image with a newer
  vchord, run `ALTER EXTENSION vchord UPDATE;` in each database that uses it, then reindex its
  vchord indexes (for Immich: `REINDEX INDEX face_index; REINDEX INDEX clip_index;`).
- **pgvector, PostGIS, pg_cron:** `ALTER EXTENSION <name> UPDATE;` per database; for PostGIS,
  `SELECT postgis_extensions_upgrade();`.
- **PostgreSQL 18:** not shipped under this image's tags. When it comes, it needs a dump and
  restore of every database.

## Build

```sh
docker build -t postgres-shared .
```

## Test

```sh
docker build -t postgres-shared:test .
bash scripts/smoke-test.sh postgres-shared:test
node --test scripts/tags.test.mjs
```

## License

The packaging in this repository is [MIT](LICENSE). The image bundles software under its own
licenses: PostgreSQL, pgvector and pg_cron (PostgreSQL License), PostGIS (GPL-2.0-or-later),
VectorChord (AGPL-3.0 or Elastic License 2.0, at your option), and firecrawl's NUQ schema in
[`runtime/nuq.sql`](runtime/nuq.sql) (AGPL-3.0).
