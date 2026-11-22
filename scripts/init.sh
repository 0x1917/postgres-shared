#!/usr/bin/env bash
# Turn a fresh copy of the template into a real image repository: fill in every
# placeholder, drop the "Using this template" README section, and delete this script.
#
#   scripts/init.sh --app myapp --title "My App" --upstream owner/myapp --port 8080 [--repo owner/name]
#
# Run it once, from anywhere inside the new repository, then commit the result.
# Requires: git, perl (both on macOS and Ubuntu).
set -euo pipefail

usage() { sed -n '5p' "$0" | sed 's/^# *//' >&2; exit 2; }

APP='' TITLE='' UPSTREAM='' PORT='' REPO=''
while [ $# -gt 0 ]; do
  case "$1" in
    --app)      APP=${2:-} ;;
    --title)    TITLE=${2:-} ;;
    --upstream) UPSTREAM=${2:-} ;;
    --port)     PORT=${2:-} ;;
    --repo)     REPO=${2:-} ;;
    -h|--help)  usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
  shift 2 || usage
done

root=$(git rev-parse --show-toplevel)
cd "$root"

if [ -z "$REPO" ]; then
  REPO=$(git remote get-url origin 2>/dev/null | sed -E 's#^.*github\.com[:/]##; s#\.git$##')
fi

# Validate before touching anything: a half-replaced tree is worse than none.
[[ "$APP" =~ ^[a-z0-9][a-z0-9._-]*$ ]]          || { echo "--app must be a lowercase image name, e.g. myapp" >&2; exit 2; }
[ -n "$TITLE" ] && [[ "$TITLE" != *[\"\\]* ]]     || { echo "--title is required, without quotes or backslashes" >&2; exit 2; }
[[ "$UPSTREAM" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "--upstream must be owner/repo" >&2; exit 2; }
[[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || { echo "--port must be 1-65535" >&2; exit 2; }
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "could not read owner/repo from origin; pass --repo" >&2; exit 2; }
[ "$REPO" != "0x1917/docker-template" ] || { echo "run this in a repository created from the template, not the template itself" >&2; exit 2; }

self=scripts/init.sh
files=()
while IFS= read -r f; do
  [ "$f" = "$self" ] || files+=("$f")
done < <(git ls-files)

# Values come in through the environment, so a title with / & or quotes needs no escaping.
APP="$APP" TITLE="$TITLE" UPSTREAM="$UPSTREAM" PORT="$PORT" REPO="$REPO" \
  perl -pi -e 's/__APP__/$ENV{APP}/g; s/__TITLE__/$ENV{TITLE}/g; s/__UPSTREAM__/$ENV{UPSTREAM}/g;
               s/__PORT__/$ENV{PORT}/g; s/__REPO__/$ENV{REPO}/g' "${files[@]}"
perl -0pi -e 's/<!-- template:start -->.*?<!-- template:end -->\n\n?//s' README.md
git rm -q "$self"

echo "filled in: app=$APP title=\"$TITLE\" upstream=$UPSTREAM port=$PORT repo=$REPO"
if git grep -nE '__(APP|TITLE|REPO|UPSTREAM|PORT)__' -- .; then
  echo "placeholders left above; fix them by hand" >&2
  exit 1
fi
echo
echo "Still to do (lint warns about each until it is gone):"
git grep -n 'TODO(template)' -- . ':(exclude).github/workflows/lint.yml' || echo "  nothing"
