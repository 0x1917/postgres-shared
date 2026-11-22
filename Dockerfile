# PostgreSQL 17 with pgvector, VectorChord, PostGIS and pg_cron, on the official image and its
# entrypoint: every POSTGRES_* variable, /docker-entrypoint-initdb.d, and the data layout behave
# exactly as documented for the official postgres image. One cluster serves apps whose
# extension needs would otherwise force one database container each (Immich: vchord + vector,
# Dawarich: postgis, firecrawl: pg_cron + its NUQ queue schema).
#
# Pinning: the base by tag and multi-arch digest, the apt packages by exact version (apt
# verifies each .deb against the signed pgdg Packages index), VectorChord by version and the
# sha256 of its release .deb. Renovate proposes every bump (renovate.json5). pgdg keeps only
# recent builds of a package in its index, so an old pin eventually stops resolving: the
# weekly canary build reports that as a red run.
FROM postgres:17.11-bookworm@sha256:665dc7b37ac52a17e298511414c21d23ffa4e6a6ef6225b3e5d59c7afb35e994

# The PostgreSQL release the base image carries; the image is tagged with it. Renovate bumps
# it together with the FROM line, and the build fails if the two disagree.
ARG UPSTREAM_VERSION=17.11

# renovate: datasource=deb depName=postgresql-17-pgvector
ARG PGVECTOR_VERSION=0.8.6-1.pgdg12+2
# renovate: datasource=deb depName=postgresql-17-postgis-3
ARG POSTGIS_VERSION=3.6.4+dfsg-2.pgdg12+1
# renovate: datasource=deb depName=postgresql-17-cron
ARG PG_CRON_VERSION=1.6.8-1.pgdg12+2
# renovate: datasource=github-releases depName=tensorchord/VectorChord
ARG VCHORD_VERSION=0.4.3
# The release asset's sha256 (GitHub lists it on the asset). A bare download has no
# signature chain, so this hash is the only check: update it with every version bump.
ARG VCHORD_SHA256=a4776ac7b1def6d4f02370227a214be50ec36c84d0af3469070120667215f4ae

RUN set -eux;                                                                              \
    [ "${PG_VERSION%%-*}" = "$UPSTREAM_VERSION" ]                                          \
      || { echo "base carries PostgreSQL ${PG_VERSION}, UPSTREAM_VERSION says ${UPSTREAM_VERSION}" >&2; exit 1; }; \
    [ "$(dpkg --print-architecture)" = amd64 ]                                             \
      || { echo "only amd64 is built and tested" >&2; exit 1; };                           \
    apt-get update;                                                                        \
    apt-get install -y --no-install-recommends ca-certificates curl;                       \
    curl -fsSL -o /tmp/vchord.deb                                                          \
      "https://github.com/tensorchord/VectorChord/releases/download/${VCHORD_VERSION}/postgresql-${PG_MAJOR}-vchord_${VCHORD_VERSION}-1_amd64.deb"; \
    echo "${VCHORD_SHA256}  /tmp/vchord.deb" | sha256sum -c -;                             \
    apt-get install -y --no-install-recommends                                             \
      "postgresql-${PG_MAJOR}-pgvector=${PGVECTOR_VERSION}"                                \
      "postgresql-${PG_MAJOR}-postgis-3=${POSTGIS_VERSION}"                                \
      "postgresql-${PG_MAJOR}-postgis-3-scripts=${POSTGIS_VERSION}"                        \
      "postgresql-${PG_MAJOR}-cron=${PG_CRON_VERSION}"                                     \
      /tmp/vchord.deb;                                                                     \
    apt-get purge -y --auto-remove curl;                                                   \
    rm -rf /var/lib/apt/lists/* /tmp/vchord.deb

# vchord and pg_cron only work when preloaded; pgvector and PostGIS need no preload and stay
# inert until CREATE EXTENSION in a database. initdb copies this sample into each NEW data
# directory, so an existing cluster keeps its own postgresql.conf (see the README).
RUN echo "shared_preload_libraries = 'vchord.so,pg_cron'" >> "/usr/share/postgresql/${PG_MAJOR}/postgresql.conf.sample"

# Runtime files are staged with COPY, installed at their target paths in one place, and the
# staging dir removed in the same layer. The NUQ schema is not in initdb.d itself: the init
# script loads it only when NUQ_DATABASE asks for it.
COPY runtime/ /tmp/app-runtime/
RUN install -D -m 755 /tmp/app-runtime/entrypoint.sh  /usr/local/bin/app-entrypoint                \
 && install -D -m 755 /tmp/app-runtime/healthcheck.sh /usr/local/bin/app-healthcheck               \
 && install -D -m 755 /tmp/app-runtime/initdb-nuq.sh  /docker-entrypoint-initdb.d/010-nuq.sh       \
 && install -D -m 644 /tmp/app-runtime/nuq.sql        /usr/local/share/postgres-shared/nuq.sql     \
 && rm -rf /tmp/app-runtime

# Every extension must land where postgres looks for it, for this PG_MAJOR.
RUN set -eux;                                                                              \
    share="/usr/share/postgresql/${PG_MAJOR}/extension"; lib="$(pg_config --pkglibdir)";   \
    for e in vector vchord postgis pg_cron; do test -f "$share/$e.control"; done;          \
    for l in vector vchord postgis-3 pg_cron; do test -f "$lib/$l.so"; done

# The official image's STOPSIGNAL (SIGINT, a fast shutdown), user (postgres, 999), VOLUME and
# EXPOSE carry over unchanged. The entrypoint wrapper only adds cron.database_name.
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=5 \
  CMD /usr/local/bin/app-healthcheck

ENTRYPOINT ["/usr/local/bin/app-entrypoint"]
CMD ["postgres"]

# Last, so the per-build values below never invalidate the cached layers above. source is
# this repository, whose v<version> releases are what 3U and similar tools look up.
ARG VCS_REF=dev
ARG BUILD_DATE=unknown
ARG BASE_NAME=unknown
ARG BASE_DIGEST=unknown
LABEL org.opencontainers.image.title="PostgreSQL Shared"                                                                         \
      org.opencontainers.image.description="PostgreSQL 17 with pgvector, VectorChord, PostGIS and pg_cron: one shared database server for every app on Unraid." \
      org.opencontainers.image.authors="0x1917 (https://github.com/0x1917)"                                                      \
      org.opencontainers.image.source="https://github.com/0x1917/postgres-shared"                                                \
      org.opencontainers.image.url="https://www.postgresql.org/"                                                                 \
      org.opencontainers.image.documentation="https://github.com/0x1917/postgres-shared#readme"                                  \
      org.opencontainers.image.licenses="MIT AND PostgreSQL AND GPL-2.0-or-later AND AGPL-3.0-only AND (AGPL-3.0-only OR Elastic-2.0)" \
      org.opencontainers.image.version="${UPSTREAM_VERSION}"                                                                     \
      org.opencontainers.image.ref.name="${UPSTREAM_VERSION}"                                                                    \
      org.opencontainers.image.revision="${VCS_REF}"                                                                             \
      org.opencontainers.image.created="${BUILD_DATE}"                                                                           \
      org.opencontainers.image.base.name="${BASE_NAME}"                                                                          \
      org.opencontainers.image.base.digest="${BASE_DIGEST}"                                                                      \
      net.unraid.docker.icon="https://raw.githubusercontent.com/0x1917/unraid-templates/master/assets/postgres-shared/icon.png"
