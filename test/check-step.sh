#!/usr/bin/env bash
# Runs the check workflow's "Check each added reference" step, taken from
# the workflow file itself, against a pull request that adds a list entry
# that is not a source reference. References are untrusted data: "-h"
# must fail the step (not be read as a help flag that exits 0), and so must
# a reference with an embedded newline. HEW_CLI names the hew-cli binary.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
: "${HEW_CLI:?set HEW_CLI to a hew-cli binary}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The step's run block: the lines indented under its "run: |", until the
# next step or the end of the file.
awk '
  /^      - name: Check each added reference$/ { step = 1; next }
  step && /^      - name:/ { exit }
  step && /^        run: \|$/ { body = 1; next }
  body { sub(/^          /, ""); print }
' "$here/.github/workflows/check.yml" > "$work/step.sh"
[ -s "$work/step.sh" ] || { echo "step not found" >&2; exit 2; }

mkdir -p "$work/runner/hew-cli"
ln -s "$HEW_CLI" "$work/runner/hew-cli/hew-cli"

fails=0
try() { # <label> <json list added by the pull request>
  local repo="$work/repo-$1"
  mkdir "$repo"
  (
    cd "$repo"
    git init -q -b main .
    git config user.email t@example.org
    git config user.name t
    echo '[]' > library.json
    git add . && git commit -qm base
    printf '%s\n' "$2" > library.json
    git commit -qam "pr"
    # The step reads HEAD^1 as the base, so give HEAD a first parent.
    RUNNER_TEMP="$work/runner" bash "$work/step.sh" > "$work/$1.out" 2>&1
  ) && { echo "FAIL $1: the step passed"; cat "$work/$1.out"; fails=$((fails + 1)); } \
    || echo "ok   $1: the step failed"
}

try dash-h '["-h"]'
try dash-dash-help '["--help"]'
try newline '["github:a/b\nx"]'
exit "$fails"
