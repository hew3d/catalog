#!/usr/bin/env bash
# Offline checks for the catalog repository. Needs a hew-cli with the
# `catalog` subcommands: set HEW_CLI to a binary, or set HEW_SOURCE_TREE to
# a hew checkout and the script builds hew-cli from it.
#
# `catalog check` refuses loopback addresses in a normal build, so nothing
# here needs the network. A source that is fetched over the network is
# covered by the tests in the hew repository.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

if [ -z "${HEW_CLI:-}" ]; then
  tree="${HEW_SOURCE_TREE:-$here/../hew-sources}"
  export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$tree/target}"
  (cd "$tree" && cargo build -q -p hew-cli)
  HEW_CLI="$CARGO_TARGET_DIR/debug/hew-cli"
fi
[ -x "$HEW_CLI" ] || { echo "no hew-cli at $HEW_CLI" >&2; exit 2; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# 1. The three lists are sorted JSON arrays with unique entries, and each
#    removed.json entry has the shape of the design (6.3).
for f in library plugins; do
  if jq -e 'type == "array" and all(.[]; type == "string") and (. == (sort | unique))' \
    "$here/$f.json" > /dev/null; then pass "$f.json is a sorted, unique array of strings"
  else fail "$f.json"; fi
done
if jq -e 'type == "array" and all(.[];
    (.source | type == "string") and (.severity == "removed" or .severity == "critical")
    and (.reason | type == "string") and ((.link // "https://x") | startswith("https://")))' \
  "$here/removed.json" > /dev/null; then pass "removed.json entries have source, severity, reason"
else fail "removed.json"; fi

# 2. A build over the committed (empty) lists writes an empty valid catalog.
out="$work/out"
if "$HEW_CLI" catalog build "$here" --out "$out" > "$work/build.txt" 2>&1 \
  && jq -e '.hew == 1 and (.sources | length == 0) and (.removed | length == 0)
            and (.built | type == "string")' "$out/catalog.json" > /dev/null; then
  pass "build on empty lists writes an empty catalog.json"
else fail "build on empty lists"; cat "$work/build.txt"; fi

# 3. A removed.json-only run: the entry is carried, no source is requested.
co="$work/removed-only"
mkdir -p "$co"
echo '[]' > "$co/library.json"; echo '[]' > "$co/plugins.json"
cat > "$co/removed.json" <<'JSON'
[{ "source": "github:example/gone", "severity": "removed",
   "reason": "A test entry.", "link": "https://example.org/why" }]
JSON
if "$HEW_CLI" catalog build "$co" --out "$work/out2" > "$work/build2.txt" 2>&1 \
  && jq -e '(.sources | length == 0) and (.removed | length == 1)
            and .removed[0].source == "github:example/gone"
            and .removed[0].severity == "removed"' "$work/out2/catalog.json" > /dev/null; then
  pass "removed.json-only build carries the removal"
else fail "removed.json-only build"; cat "$work/build2.txt"; fi

# 4. A removed source that is also listed is never requested: the build
#    finishes offline and reports it as removed.
co3="$work/removed-listed"
mkdir -p "$co3"
echo '["github:example/gone"]' > "$co3/library.json"; echo '[]' > "$co3/plugins.json"
cp "$co/removed.json" "$co3/removed.json"
if "$HEW_CLI" catalog build "$co3" --out "$work/out3" > "$work/build3.txt" 2>&1 \
  && grep -q '1 removed' "$work/build3.txt" \
  && jq -e '(.sources | length == 0) and (.removed | length == 1)' \
       "$work/out3/catalog.json" > /dev/null; then
  pass "a listed and removed source is not requested"
else fail "listed and removed source"; cat "$work/build3.txt"; fi

# 5. A malformed list is refused by the build.
co4="$work/bad"
mkdir -p "$co4"
echo '{}' > "$co4/library.json"; echo '[]' > "$co4/plugins.json"; echo '[]' > "$co4/removed.json"
if "$HEW_CLI" catalog build "$co4" --out "$work/out4" > /dev/null 2>&1; then
  fail "a list that is not an array was accepted"
else pass "a list that is not an array is refused"; fi

# 6. check refuses a loopback address in this build (never a network call).
if "$HEW_CLI" catalog check "web:https://127.0.0.1:1/hew.json" > "$work/check.txt" 2>&1; then
  fail "loopback reference passed check"; cat "$work/check.txt"
else pass "check refuses a loopback reference ($(head -n1 "$work/check.txt"))"; fi

# 7. The workflows pass actionlint, when it is installed.
if command -v actionlint > /dev/null; then
  if actionlint "$here"/.github/workflows/*.yml; then pass "actionlint"
  else fail "actionlint"; fi
else
  echo "skip actionlint (not installed)"
fi

# 8. The check workflow's base commit (the merge commit's first parent) does
#    not go stale when the base branch advances.
if "$here/test/stale-base.sh"; then pass "stale-base"; else fail "stale-base"; fi

# 9. A reference that looks like a flag, or holds a newline, fails the
#    check workflow's step instead of passing as help.
if HEW_CLI="$HEW_CLI" "$here/test/check-step.sh"; then pass "check step refuses odd references"
else fail "check step refuses odd references"; fi

echo
if [ "$fails" -eq 0 ]; then echo "all checks passed"; else echo "$fails failed"; exit 1; fi
