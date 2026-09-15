#!/bin/sh
set -eu

usage() {
  cat <<'USAGE'
usage: scripts/site-update.sh main <webdir>
       scripts/site-update.sh pr <N> <builddir>
       scripts/site-update.sh remove-pr <N>

Rewrites the `site` branch, which is exactly what GitHub Pages serves.
  main       replaces everything except pr/ with <webdir> (explorer page + dmd.wasm)
  pr         installs <builddir> (dmd.wasm + meta.json) as pr/<N>
  remove-pr  drops pr/<N>
Then builds of merged/closed PRs are pruned (skip with SITE_KEEP_CLOSED=1),
pr/index.json is regenerated and the tree is force-pushed as a single commit,
so the branch never accumulates old binaries.

Environment: SITE_REPO (default $GITHUB_REPOSITORY, else dkorpel/dmd-explorer),
SITE_BRANCH (default site), SITE_URL (clone/push URL override, for testing),
GITHUB_TOKEN (push auth), GH_TOKEN (gh, for pruning), SITE_DIR (checkout dir).
USAGE
}

CMD="${1:-}"
[ -n "$CMD" ] || { usage >&2; exit 1; }
shift

REPO="${SITE_REPO:-${GITHUB_REPOSITORY:-dkorpel/dmd-explorer}}"
BRANCH="${SITE_BRANCH:-site}"
SITE="${SITE_DIR:-${RUNNER_TEMP:-$PWD}/site-checkout}"
if [ -n "${SITE_URL:-}" ]; then URL="$SITE_URL"
elif [ -n "${GITHUB_TOKEN:-}" ]; then URL="https://x-access-token:${GITHUB_TOKEN}@github.com/$REPO.git"
else URL="https://github.com/$REPO.git"; fi

KEEP=
case "$CMD" in
  main)
    WEB="$(cd "$1" && pwd)"
    MSG="main build $(date -u +%Y-%m-%dT%H:%M:%SZ)" ;;
  pr)
    N="$1"
    BUILD="$(cd "$2" && pwd)"
    KEEP="$N"
    MSG="PR #$N build $(date -u +%Y-%m-%dT%H:%M:%SZ)" ;;
  remove-pr)
    N="$1"
    MSG="remove PR #$N" ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 1 ;;
esac

rm -rf "$SITE"
if ! git clone -q --depth 1 -b "$BRANCH" "$URL" "$SITE" 2>/dev/null; then
  echo "branch $BRANCH does not exist yet; creating it"
  git init -q "$SITE"
fi
cd "$SITE"

if [ "$CMD" != main ] && [ ! -f index.html ]; then
  echo "the $BRANCH branch has no explorer page yet; run the Deploy to GitHub Pages workflow (site-update.sh main) first" >&2
  exit 1
fi

case "$CMD" in
  main)
    find . -mindepth 1 -maxdepth 1 ! -name pr ! -name .git -exec rm -rf {} +
    cp -R "$WEB"/. . ;;
  pr)
    rm -rf "pr/$N"
    mkdir -p pr
    cp -R "$BUILD" "pr/$N" ;;
  remove-pr)
    rm -rf "pr/$N" ;;
esac

if [ -z "${SITE_KEEP_CLOSED:-}" ] && [ -d pr ] && command -v gh >/dev/null; then
  for d in pr/*/; do
    n="${d#pr/}"
    n="${n%/}"
    [ -f "$d/meta.json" ] || continue
    [ "$n" = "$KEEP" ] && continue
    repo="$(sed -n 's/.*"repo":"\([^"]*\)".*/\1/p' "$d/meta.json")"
    state="$(gh pr view "$n" -R "${repo:-dlang/dmd}" --json state --jq .state 2>/dev/null || echo UNKNOWN)"
    case "$state" in
      MERGED|CLOSED) echo "pruning pr/$n ($state)"; rm -rf "$d" ;;
    esac
  done
fi

if [ -d pr ]; then
  first=1
  {
    printf '['
    for n in $(ls pr | grep -E '^[0-9]+$' | sort -rn); do
      [ -f "pr/$n/meta.json" ] || continue
      [ "$first" = 1 ] || printf ','
      first=0
      cat "pr/$n/meta.json"
    done
    printf ']\n'
  } > pr/index.json
fi

git checkout -q --orphan fresh-site
git add -A
git -c user.name="dmd-explorer bot" -c user.email="dmd-explorer@users.noreply.github.com" commit -q --allow-empty -m "$MSG"
git push -q --force "$URL" "HEAD:refs/heads/$BRANCH"
echo "pushed $BRANCH: $MSG"
du -sh --exclude=.git . | cut -f1 | sed 's/^/site size: /'
