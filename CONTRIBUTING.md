# Contributing

This repository packages [__TITLE__](https://github.com/__UPSTREAM__) into a single
container image and publishes it. It holds no application code: the `Dockerfile`,
the `runtime/` scripts it installs, and the CI workflows are the whole of it.

## Where a report or a change belongs

| Subject                                                                     | Goes to                                                                          |
| --------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| The image: build, entrypoint, PUID/PGID, CI, how the container behaves      | Here: [issues](https://github.com/__REPO__/issues) and pull requests             |
| The Unraid template: fields, defaults, artwork, the Docker tab entry        | [`0x1917/unraid-templates`](https://github.com/0x1917/unraid-templates/issues)   |
| __TITLE__ itself                                                            | Upstream: [__UPSTREAM__](https://github.com/__UPSTREAM__/issues)                 |
| A security vulnerability                                                    | [SECURITY.md](SECURITY.md), privately, not a public issue                        |

If you are unsure, open it here and it will be moved rather than closed.

## Run the checks before you open a pull request

CI runs all of these, and a pull request that fails them will not be reviewed until it passes:

```sh
node --test scripts/tags.test.mjs
bash scripts/check-build-inputs.sh
shellcheck -x -S warning runtime/*.sh scripts/*.sh
actionlint .github/workflows/*.yml
docker build -t __APP__:test . && bash scripts/smoke-test.sh __APP__:test
```

## The invariants the tests enforce

- **No `USER` instruction.** The entrypoint must start as root to remap `app` to
  `PUID`/`PGID` and fix `/data`, then drops privileges with `gosu`.
- **The app is exec'd.** It stays tini's direct child, so it receives stop signals itself
  and its exit status is the container's. The smoke test checks for a clean `docker stop`.
- **Git tags are `v<version>`**, with `v<version>-r<n>` for a rebuild, ordered by semver
  (`scripts/tags.mjs`).

## Changing the image

- Keep the privilege model intact: nothing runs as root after the entrypoint's setup.
- Comments explain *why* a thing is done, especially where the obvious alternative fails. A
  change that removes one needs to replace it with the reason.
- If you change behaviour a user can see, update [README.md](README.md). If the change affects
  what the image needs at run time, the Unraid template needs a matching change, in the
  templates repository, as a separate pull request.

## Versions, tags, and releases

Do not bump `UPSTREAM_VERSION`, create a git tag, or edit the publish workflow's release logic
in a pull request: Renovate proposes upstream bumps and the maintainer cuts releases.

## Pull request shape

- One concern per pull request. A formatting sweep mixed with a fix will be asked to split.
- Say why in the description, not just what. The diff already says what.
- Do not reorder `Dockerfile` layers for tidiness; the order is the cache.
- Do not reformat files you did not otherwise touch.

## Licensing

This repository is [MIT](LICENSE). There is no CLA and no contributor agreement: by opening a
pull request you agree your contribution is licensed under the same terms. __TITLE__ itself
carries its own license in [`__UPSTREAM__`](https://github.com/__UPSTREAM__).
