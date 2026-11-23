#!/usr/bin/env bash
# The check workflow diffs the pull request's checkout (the merge ref)
# against a base commit. The event's recorded base sha can go stale: when
# the base branch advances after the merge ref was computed, the old sha
# lacks the base's own additions and they would be reported as the pull
# request's. The merge commit's first parent is the base the merge was
# computed against, so it cannot go stale. This builds that situation and
# checks both choices.
set -euo pipefail

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"
git init -q -b main .
git config user.email t@example.org
git config user.name t

echo '["github:a/a"]' > library.json
git add . && git commit -qm base
stale_base="$(git rev-parse HEAD)"        # what the event recorded

git checkout -q -b pr
echo '["github:a/a","github:c/c"]' > library.json
git commit -qam "pr adds c"

git checkout -q main
echo '["github:a/a","github:b/b"]' > library.json
git commit -qam "main adds b after the branch point"

# The merge ref GitHub builds: the PR merged into the advanced base.
git checkout -q --detach main
git merge -q --no-ff --no-commit pr > /dev/null 2>&1 || true   # both sides edit the list
echo '["github:a/a","github:b/b","github:c/c"]' > library.json
git add library.json && git commit -qm merge

added() { # <base sha>: references the checkout has that the base lacks
  git show "$1:library.json" > base.json
  jq -r --slurpfile base base.json '.[] | select(. as $r | $base[0] | index($r) | not)' library.json
}

fails=0
old="$(added "$stale_base" | paste -sd, -)"
new="$(added "$(git rev-parse HEAD^1)" | paste -sd, -)"
if [ "$old" = "github:b/b,github:c/c" ]; then echo "ok   stale base sha reports b as added (the old behavior): $old"
else echo "FAIL old behavior not reproduced: $old"; fails=1; fi
if [ "$new" = "github:c/c" ]; then echo "ok   HEAD^1 reports only the pull request's c: $new"
else echo "FAIL HEAD^1 reported: $new"; fails=1; fi
exit "$fails"
