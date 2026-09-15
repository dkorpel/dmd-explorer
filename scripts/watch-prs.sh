#!/bin/sh
set -eu

usage() {
  cat <<'USAGE'
usage: scripts/watch-prs.sh

Compares the open PRs of $PR_REPO that carry $WATCH_LABEL with the builds
listed in pr/index.json on the site branch, then dispatches try-pr.yml:
  build   labeled PR with no build, or whose head moved since the build
  remove  build with "source":"label" whose PR lost the label or was closed
Builds with "applied":"manual" (hand-resolved conflicts) are never rebuilt
automatically; a head change is reported instead. PRs with a try-pr run
already queued or running are skipped.

Environment: PR_REPO (default dlang/dmd), WATCH_LABEL (default try-it),
SITE_REPO (default $GITHUB_REPOSITORY, else dkorpel/dmd-explorer),
SITE_BRANCH (default site), GH_TOKEN (gh: read PRs, dispatch workflows),
DRY_RUN=1 (print the actions without dispatching), INDEX_JSON (use this
instead of fetching pr/index.json, for testing).
USAGE
}
[ "${1:-}" = -h ] || [ "${1:-}" = --help ] && { usage; exit 0; }

PR_REPO="${PR_REPO:-dlang/dmd}"
LABEL="${WATCH_LABEL:-try-it}"
SITE_REPO="${SITE_REPO:-${GITHUB_REPOSITORY:-dkorpel/dmd-explorer}}"
SITE_BRANCH="${SITE_BRANCH:-site}"
WORKFLOW=try-pr.yml

INDEX="${INDEX_JSON:-$(gh api "repos/$SITE_REPO/contents/pr/index.json?ref=$SITE_BRANCH" --jq .content 2>/dev/null | base64 -d || echo '[]')}"
LABELED="$(gh pr list -R "$PR_REPO" --label "$LABEL" --state open --limit 200 --json number,headRefOid --jq '.[] | "\(.number) \(.headRefOid)"')"
index_field() { printf '%s' "$INDEX" | tr -d '\n' | sed -n "s|.*{[^}]*\"pr\":$1,\"repo\":\"$PR_REPO\"[^}]*\"$2\":\"\([^\"]*\)\"[^}]*}.*|\1|p"; }
index_prs() { printf '%s' "$INDEX" | tr -d '\n' | grep -o '"pr":[0-9]*,"repo":"[^"]*"' | sed 's/"pr":\([0-9]*\),"repo":"\(.*\)"/\1 \2/'; }
labeled_head() { printf '%s\n' "$LABELED" | awk -v n="$1" '$1 == n { print $2 }'; }
BUSY="$(for s in queued in_progress waiting requested pending; do
  gh run list -R "$SITE_REPO" -w "$WORKFLOW" -s "$s" --limit 50 --json displayTitle --jq '.[].displayTitle'
done | sed -n 's/^Build PR #\([0-9]*\).*/\1/p' | sort -u)"

busy() { printf '%s\n' "$BUSY" | grep -qx "$1"; }

dispatch() {
  if busy "$1"; then
    echo "skip PR #$1: a $WORKFLOW run is already queued or running"
    return 0
  fi
  echo "dispatch $WORKFLOW: pr=$1 action=$2"
  [ -n "${DRY_RUN:-}" ] || gh workflow run "$WORKFLOW" -R "$SITE_REPO" -f "pr=$1" -f "repo=$PR_REPO" -f "action=$2" -f source=label
}

echo "== $PR_REPO PRs labeled '$LABEL':" $(printf '%s\n' "$LABELED" | awk '{ print $1 }')
echo "== builds on $SITE_REPO@$SITE_BRANCH:" $(index_prs | awk '{ print $1 }')

printf '%s\n' "$LABELED" | while read -r n head; do
  [ -n "$n" ] || continue
  built="$(index_field "$n" head)"
  if [ -z "$built" ]; then
    echo "PR #$n: no build yet"
    dispatch "$n" build
    continue
  fi
  if [ "$built" = "$head" ]; then
    echo "PR #$n: build is current ($head)"
  elif [ "$(index_field "$n" applied)" = manual ]; then
    echo "PR #$n: head moved $built -> $head but the build was hand-resolved; rerun $WORKFLOW with preapplied by hand"
  else
    echo "PR #$n: head moved $built -> $head"
    dispatch "$n" build
  fi
done

index_prs | while read -r n repo; do
  [ "$repo" = "$PR_REPO" ] || continue
  [ "$(index_field "$n" source)" = label ] || continue
  [ -z "$(labeled_head "$n")" ] || continue
  echo "PR #$n: label gone or PR closed"
  dispatch "$n" remove
done
