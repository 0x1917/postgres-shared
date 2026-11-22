# __TITLE__

[![Version](https://img.shields.io/docker/v/0x1917/__APP__)](https://hub.docker.com/r/0x1917/__APP__)
[![Build](https://github.com/__REPO__/actions/workflows/build.yml/badge.svg)](https://github.com/__REPO__/actions/workflows/build.yml)
[![Lint](https://github.com/__REPO__/actions/workflows/lint.yml/badge.svg)](https://github.com/__REPO__/actions/workflows/lint.yml)
[![Pulls](https://img.shields.io/docker/pulls/0x1917/__APP__)](https://hub.docker.com/r/0x1917/__APP__)
[![Image size](https://img.shields.io/docker/image-size/0x1917/__APP__)](https://hub.docker.com/r/0x1917/__APP__)
[![Platform](https://img.shields.io/badge/platform-linux%2Famd64-blue?logo=linux&logoColor=white)](#run)
[![License](https://img.shields.io/github/license/__REPO__)](https://github.com/__REPO__/blob/master/LICENSE)

<!-- template:start -->
## Using this template

This repository is the starting point for packaging an upstream app as an Unraid container,
with the same build, test, and publish chain as other existing repos.

1. **Create the repository:** on GitHub, **Use this template** > **Create a new repository**.
2. **Fill in the names:**
   ```sh
   scripts/init.sh --app myapp --title "My App" --upstream owner/myapp --port 8080
   ```
   | Option       | Becomes                                                       |
   | ------------ | ------------------------------------------------------------- |
   | `--app`      | the image `0x1917/<app>`, the container, and test names       |
   | `--title`    | the human-readable name in docs, labels, and release notes    |
   | `--upstream` | the upstream GitHub `owner/repo` Renovate and releases follow |
   | `--port`     | the port the app listens on inside the container              |
   | `--repo`     | this repository (default: read from `git remote origin`)      |

   It replaces every placeholder, removes this section and itself, and prints what is left.
3. **Finish the `TODO(template)` spots:** the install step, start command, and health URL in
   the `Dockerfile`; the app-specific checks in `scripts/smoke-test.sh`; and the upstream
   source in `renovate.json5`. Lint warns about each until it is gone.
4. **Set up the repository:**
   - add the `DOCKERHUB_TOKEN` secret (Docker Hub, Read & Write)
   - enable the Renovate app for the repository
   - copy the `master` ruleset from an existing repository (pull requests, `build` and `lint` checks)
5. **Publish:** Actions > build > Run workflow with `force_publish`.
6. **Add the Unraid template** to [`0x1917/unraid-templates`](https://github.com/0x1917/unraid-templates).
<!-- template:end -->

[__TITLE__](https://github.com/__UPSTREAM__) repackaged as a container for Unraid. Install it
from the Community Applications plugin, or manually with the template from
[0x1917/unraid-templates](https://github.com/0x1917/unraid-templates/blob/master/templates/my-__APP__.xml)
(copy it to `/boot/config/plugins/dockerMan/templates-user/`).

## Build

```sh
docker build -t __APP__ .
```

## Run

```sh
docker run -d                          \
  --name __APP__                       \
  --restart unless-stopped             \
  -p __PORT__:__PORT__                 \
  -v /mnt/user/appdata/__APP__:/data   \
  0x1917/__APP__
```

## Environment

| Variable        | Default      | Meaning                                                                         |
| --------------- | ------------ | ------------------------------------------------------------------------------- |
| `PUID` / `PGID` | `99` / `100` | The user the app runs as. `/data` is re-owned to it on start; nothing else is.  |
| `UMASK`         | `022`        | Mask for the files the app creates.                                             |

## Test

```sh
docker build -t __APP__:test .
bash scripts/smoke-test.sh __APP__:test
node --test scripts/tags.test.mjs
```
