#!/usr/bin/env bash
# Run the pack's test suite.
#
#   ./tests/run.sh              everything
#   ./tests/run.sh lint         just tests/test-lint.sh
#
# No dependencies, nothing to install - the same rule the pack itself follows.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO="${REPO:-$(cd "$HERE/.." && pwd)}"

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/pack-tests.XXXXXX")"
trap 'rm -rf "$TMPROOT"' EXIT

# --- prove the harness can fail before trusting a single green result ---------
#
# Rule 12 once shipped unable to fail: it printed its error from inside a
# subshell and returned 0, so it reported problems without ever failing a build.
# A suite with that defect reports every file clean and hides everything. So the
# first thing this runner does is make an assertion fail on purpose and check
# that the harness noticed.
selftest() {
  local out
  out="$(
    export REPO TEST_TMP="$TMPROOT/selftest"
    mkdir -p "$TEST_TMP"
    # shellcheck source=/dev/null
    source "$HERE/lib.sh"
    assert_eq "deliberate failure" "expected" "actual"
    assert_ok "deliberate refusal" false
    assert_refuses "wrong message is not a pass" "this-string-never-appears" false
    finish
  )"
  local rc=$?
  local fails
  fails="$(printf '%s' "$out" | sed -n 's/.*[0-9]* passed, \([0-9]*\) failed.*/\1/p')"
  if [ "$rc" -eq 0 ]; then
    printf 'harness self-test FAILED: three broken assertions exited 0\n' >&2
    return 1
  fi
  if [ "$fails" != "3" ]; then
    printf 'harness self-test FAILED: expected 3 failures, harness counted %s\n' "${fails:-none}" >&2
    return 1
  fi
  printf 'harness self-test ok - a failing assertion fails the run\n'
}

selftest || exit 1

# --- run the files ------------------------------------------------------------
want="${1:-}"
failed_files=""
total=0

for f in "$HERE"/test-*.sh; do
  name="$(basename "$f" .sh)"; name="${name#test-}"
  [ -n "$want" ] && [ "$name" != "$want" ] && continue
  total=$((total + 1))
  printf '\n=== %s ===\n' "$name"
  TEST_TMP="$TMPROOT/$name"
  mkdir -p "$TEST_TMP"
  if ! REPO="$REPO" TEST_TMP="$TEST_TMP" bash "$f"; then
    failed_files="$failed_files $name"
  fi
done

if [ "$total" -eq 0 ]; then
  printf '\nno test file matched %s\n' "${want:-*}" >&2
  exit 1
fi

printf '\n'
if [ -n "$failed_files" ]; then
  printf 'FAILED:%s\n' "$failed_files"
  exit 1
fi
printf 'all %d test files passed\n' "$total"
