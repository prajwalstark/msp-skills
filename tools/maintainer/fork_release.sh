#!/usr/bin/env bash
# fork_release.sh - cut this fork's own GitHub Releases, one tag per push.
#
# The installers default to MSP_SKILLS_OWNER=prajwalstark, so they download
# binaries from THIS repository's releases. Each connector needs a sealed
# release here before its installer works. This script tags each connector at
# its current manifest version, pinned to one commit, and pushes the tags one
# at a time (more than three tags in a single push fires no workflow run).
#
# Every tag is endorsed by check_release_pipeline.py first, so a commit whose
# release.yml would seal an empty release is refused before anything is pushed.
# A tag that already exists on origin is skipped, so re-running is safe.
#
# Usage:
#   tools/maintainer/fork_release.sh <commit>              # every connector
#   tools/maintainer/fork_release.sh <commit> servosity    # just these slugs
#
# Before the first run, see FORK.md (Actions and immutable releases must be on).

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <commit> [slug ...]" >&2
  exit 2
fi

cd "$(git rev-parse --show-toplevel)"

case "$(git remote get-url origin)" in
  *[Ss]ervosity/msp-skills*)
    echo "origin points at upstream Servosity/msp-skills; refusing to tag it." >&2
    exit 1 ;;
esac

SHA="$(git rev-parse --verify "$1^{commit}")"
shift

if [ "$#" -gt 0 ]; then
  SLUGS="$*"
else
  SLUGS="$(python3 - <<'PY'
import sys
sys.path.insert(0, "tools/maintainer")
import registry
print(" ".join(s for s in sorted(registry.skills()) if not registry.is_markdown_only(s)))
PY
)"
fi

pushed=0
for slug in ${SLUGS}; do
  manifest="skills/${slug}/manifest.json"
  if [ ! -f "${manifest}" ]; then
    echo "no ${manifest}; skipping ${slug}" >&2
    continue
  fi
  version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "${manifest}")"
  tag="${slug}-v${version}"

  if git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
    echo "skip   ${tag} (already on origin)"
    continue
  fi

  # A local tag left by an interrupted run is fine only if it names this SHA;
  # the probe's --pre-push mode then treats local existence as no conflict.
  probe_mode=""
  if local_sha="$(git rev-parse -q --verify "refs/tags/${tag}^{commit}")"; then
    if [ "${local_sha}" != "${SHA}" ]; then
      echo "REFUSED ${tag}: a local tag already points at ${local_sha}, not ${SHA}." >&2
      echo "  Inspect it, then 'git tag -d ${tag}' if it is stale." >&2
      exit 1
    fi
    probe_mode="--pre-push"
  fi

  if ! python3 tools/maintainer/check_release_pipeline.py --tag "${tag}" --sha "${SHA}" ${probe_mode} >/dev/null; then
    echo "REFUSED ${tag} at ${SHA}; run check_release_pipeline.py --tag ${tag} --sha ${SHA} for why." >&2
    exit 1
  fi

  [ -n "${probe_mode}" ] || git tag "${tag}" "${SHA}"
  if ! git push origin "refs/tags/${tag}"; then
    git tag -d "${tag}" >/dev/null
    echo "push of ${tag} failed; local tag removed so a re-run starts clean." >&2
    exit 1
  fi
  echo "pushed ${tag} -> ${SHA}"
  pushed=$((pushed + 1))
  sleep 5
done

echo "done: ${pushed} tag(s) pushed. Watch the Release runs in the Actions tab;"
echo "a release only counts once it is PUBLISHED with its full asset set."
