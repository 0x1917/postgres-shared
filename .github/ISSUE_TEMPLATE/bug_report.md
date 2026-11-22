---
name: Bug report
about: Report a problem with the image or its entrypoint
title: ""
labels: bug
assignees: ""
---

**What fails**
<!-- One sentence: what does not work, and what you expected instead. -->

**How the container runs**

- Image and tag: <!-- 0x1917/__APP__:<version> or 0x1917/__APP__:latest -->
- Deployed with: <!-- Unraid template, docker run, or docker compose -->
- Unraid version, or host distribution, kernel and Docker version:
- CPU architecture: <!-- this image is built for x86_64 only -->
- Data path: <!-- new install or an existing /data directory -->

**Settings in use**
<!-- Fill in the ones you changed. Delete the rest. -->

- PUID / PGID:
- Reverse proxy in front: <!-- yes/no, and which one -->

**Steps to reproduce**

1.
2.
3.

**Logs**
<!-- docker logs <container>, or Docker tab > Logs. Keep the failing start.
Remove any token, password or key before pasting. -->

```text

```

**Does it fail on another tag?**
<!-- If you run :latest, try the same steps on the previous version tag. That
separates a packaging regression from an upstream one. -->

**Additional context**
<!-- Anything else that helps.

Two kinds of report belong elsewhere, not here:
- the Unraid template, its fields, its defaults, or the artwork:
  https://github.com/0x1917/unraid-templates/issues
- a bug inside __TITLE__ itself:
  https://github.com/__UPSTREAM__/issues -->
