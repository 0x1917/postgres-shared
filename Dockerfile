FROM debian:trixie-slim

# The upstream release this image is built from. Renovate bumps it (renovate.json5).
ARG UPSTREAM_VERSION=0.0.0

# tini: PID 1 that forwards stop signals and reaps orphans. gosu: the entrypoint's drop
# from root to PUID/PGID. curl: the healthcheck.
RUN apt-get update                              \
 && apt-get install -y --no-install-recommends  \
      ca-certificates                           \
      curl                                      \
      gosu                                      \
      tini                                      \
 && rm -rf /var/lib/apt/lists/*

# TODO(template): install __TITLE__ at ${UPSTREAM_VERSION}, e.g. from an npm package, a
# release tarball (pin its sha256), or a COPY --from= of upstream's own image.

# The unprivileged user the app runs as; app-entrypoint remaps it to PUID/PGID at start.
RUN useradd --system --create-home --uid 1000 --user-group app \
 && mkdir -p /data

# Runtime files are staged with COPY, installed at their target paths in one place, and the
# staging dir removed in the same layer.
COPY runtime/ /tmp/app-runtime/
RUN install -D -m 755 /tmp/app-runtime/entrypoint.sh   /usr/local/bin/app-entrypoint   \
 && install -D -m 755 /tmp/app-runtime/healthcheck.sh  /usr/local/bin/app-healthcheck  \
 && rm -rf /tmp/app-runtime

ENV PUID=99   \
    PGID=100  \
    PORT=__PORT__

# Starts as root; app-entrypoint remaps app to PUID/PGID and drops to it via gosu.
WORKDIR /data
VOLUME ["/data"]
EXPOSE __PORT__

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD /usr/local/bin/app-healthcheck

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/app-entrypoint"]
# TODO(template): the app's start command.
CMD ["__APP__"]

# Last, so the per-build values below never invalidate the cached layers above. source is
# this repository, whose v<version> releases are what 3U and similar tools look up. The
# net.unraid.docker labels give the Docker tab an icon and a WebUI link even for a
# container not created from the template (docker run, compose).
ARG VCS_REF=dev
ARG BUILD_DATE=unknown
ARG BASE_NAME=unknown
ARG BASE_DIGEST=unknown
LABEL org.opencontainers.image.title="__TITLE__"                                                                         \
      org.opencontainers.image.description="__TITLE__ packaged for Unraid."                                              \
      org.opencontainers.image.authors="0x1917 (https://github.com/0x1917)"                                              \
      org.opencontainers.image.source="https://github.com/__REPO__"                                                      \
      org.opencontainers.image.url="https://github.com/__UPSTREAM__"                                                     \
      org.opencontainers.image.documentation="https://github.com/__REPO__#readme"                                        \
      org.opencontainers.image.licenses="MIT"                                                                            \
      org.opencontainers.image.version="${UPSTREAM_VERSION}"                                                             \
      org.opencontainers.image.ref.name="${UPSTREAM_VERSION}"                                                            \
      org.opencontainers.image.revision="${VCS_REF}"                                                                     \
      org.opencontainers.image.created="${BUILD_DATE}"                                                                   \
      org.opencontainers.image.base.name="${BASE_NAME}"                                                                  \
      org.opencontainers.image.base.digest="${BASE_DIGEST}"                                                              \
      net.unraid.docker.icon="https://raw.githubusercontent.com/0x1917/unraid-templates/master/assets/__APP__/icon.png"  \
      net.unraid.docker.webui="http://[IP]:[PORT:__PORT__]/"
