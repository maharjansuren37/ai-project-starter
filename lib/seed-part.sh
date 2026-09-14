#!/usr/bin/env bash
# Turn a directory into a part of a multi-part product.
#
# Shared by new-project.sh (creating parts from scratch) and convert-to-parts.sh
# (splitting an existing project). One copy, because the two callers producing
# subtly different parts is exactly the failure this pack keeps finding: every
# file individually valid, the mechanism between them broken.
#
# Usage: seed-part.sh <product-root> <part-name> [--quiet]
#
# Reports what it made, because README documents it as the way to add a part to
# an existing product - and a user-facing command that creates a directory, a
# full set of skills, a status file and two list entries while printing nothing
# leaves the user to go and check. `--quiet` is for the two callers above, which print
# their own summary and would otherwise repeat it once per part.
#
# Idempotent. Safe over a directory that already has the workflow in it -
# install.sh keeps files you own.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ROOT="${1:?seed-part.sh needs a product root}"
PART="${2:?seed-part.sh needs a part name}"
QUIET=""
[ "${3:-}" = "--quiet" ] && QUIET=1

# A part is a directory under the product root, and it may be nested:
# `apps/web-app` is the shape every JavaScript workspace uses, and refusing it
# meant the most common monorepo layout could not be represented at all.
#
# What must still be refused is anything that escapes the product root.
# `--parts '../x,api'` once created a sibling of the project and reported
# success, because the caller that had this guard was convert-to-parts.sh and
# the caller that did not was new-project.sh. The guard lives here, at the one
# point both callers pass through. Two copies of a rule is how the rule drifts.
PART_PATH="$PART"
case "$PART_PATH" in
  ""|/*|*\\*|*[[:space:]]*|*//*)
    echo "seed-part.sh: not a usable part path: '$PART_PATH'" >&2
    echo "  A part is a directory under the product root. It may be nested" >&2
    echo "  (apps/web-app), but may not be absolute, contain a backslash," >&2
    echo "  a space, or an empty segment." >&2
    exit 1 ;;
esac

# Every segment is checked, not just the whole string: 'apps/../../x' passes a
# naive test for a leading '..' and still escapes.
DEPTH=0
_ifs="$IFS"; IFS=/
for _seg in $PART_PATH; do
  case "$_seg" in
    ""|.|..|-*)
      IFS="$_ifs"
      echo "seed-part.sh: not a usable part path: '$PART_PATH'" >&2
      echo "  The segment '$_seg' may not be '.', '..', empty, or start with '-'." >&2
      exit 1 ;;
  esac
  DEPTH=$((DEPTH + 1))
done
IFS="$_ifs"

# `Product root:` is read by spec, build, ship, autopilot and orchestrate to
# resolve every cross-part path. It was hardcoded to '..', which is correct only
# for a part one level down - a nested part resolved the board to `apps/` and
# found nothing, silently.
UP=".."
_i=1
while [ "$_i" -lt "$DEPTH" ]; do UP="../$UP"; _i=$((_i + 1)); done

# The part's NAME is the last segment. It names the status file and the board
# entry, both of which are flat.
PART="${PART_PATH##*/}"

# Checked HERE, before anything is created. It used to sit ~70 lines below, after
# the product root's AGENTS.md had already been given this part's entry - and the
# check requires that entry to be absent, so it could never fire. A guard whose
# own precondition is destroyed by an earlier write reads exactly like a working
# one. Validating before the first mkdir also means a refusal leaves nothing
# half-made.
# The status file and board entry are keyed on the part's NAME, not its path, so
# `apps/web` and `services/web` would share one file - and two parts writing one
# status file is the exact collision the board exists to prevent. Refuse it.
if [ -f "$ROOT/blueprint/status/$PART.md" ] \
   && [ -f "$ROOT/AGENTS.md" ] \
   && ! grep -q '^- `'"$PART_PATH"'/`' "$ROOT/AGENTS.md" \
   && grep -q '^- `[^`]*'"$PART"'/`' "$ROOT/AGENTS.md"; then
  echo "seed-part.sh: a different part is already called '$PART'" >&2
  echo "  Status files and board entries are keyed on the last path segment," >&2
  echo "  so '$PART_PATH' would share one with it. Rename one of them." >&2
  exit 1
fi

DIR="$ROOT/$PART_PATH"

mkdir -p "$DIR"
"$HERE/install.sh" --target "$DIR" >/dev/null

# This part's blueprint is its own; the product plan lives one level up. install.sh
# writes a stub when none is present, so remove it after rather than before.
rm -f "$DIR/blueprint/project-plan.md"

# The Part / Product root fields are read by spec, build, ship, autopilot and
# orchestrate to resolve every cross-part path. A part missing them does not fail
# loudly - each session silently resolves the board to the part's own blueprint,
# where no other part is looking. So substitution is verified, not assumed.
python3 - "$DIR/AGENTS.md" "$PART" "$UP" <<'PYEOF'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); part = sys.argv[2]; up = sys.argv[3]
s = p.read_text()
fields = (f"- Part: {part}\n"
          f"- Product root: {up}\n\n"
          "**`blueprint/` means this part's blueprint.** The shared product plan is at\n"
          f"`{up}/blueprint/project-plan.md` and the coordination board at\n"
          f"`{up}/blueprint/orchestration.md`. Read the board before starting work.")
marker = re.compile(r"<!-- MULTI-PART MARKER.*?-->", re.S)
if marker.search(s):
    s = marker.sub(fields, s, count=1)
elif re.search(r"^- Part:", s, re.M):
    sys.exit(0)          # already a part, nothing to do
else:
    # No marker and no fields - an AGENTS.md edited past recognition. Append
    # rather than give up: the fields must exist somewhere or the part is
    # invisible to the coordinator.
    s = s.rstrip() + "\n\n## Part of a multi-part product\n\n" + fields + "\n"
p.write_text(s)
PYEOF

grep -q '^- Part: '"$PART"'$' "$DIR/AGENTS.md" \
  || { echo "seed-part.sh: failed to write 'Part: $PART' into $DIR/AGENTS.md" >&2; exit 1; }
grep -q "^- Product root: $UP\$" "$DIR/AGENTS.md" \
  || { echo "seed-part.sh: failed to write 'Product root: $UP' into $DIR/AGENTS.md" >&2; exit 1; }

# The product root's AGENTS.md lists the parts, and it is what a session opening
# the root reads first. Adding a part without listing it there leaves the root
# describing a product that no longer exists - so this is appended here rather
# than left to whoever ran the script to remember.
if [ -f "$ROOT/AGENTS.md" ] && ! grep -q '^- `'"$PART_PATH"'/`' "$ROOT/AGENTS.md"; then
  python3 - "$ROOT/AGENTS.md" "$PART_PATH" <<'PYEOF'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); part = sys.argv[2]
s = p.read_text()
entry = f"- `{part}/` - <what this part is>"

# Scope strictly to the "## The parts" section. Other sections of this file are
# also bullet lists of backticked paths - "What is here" lists `contracts/` and
# `dev-notes/` in the identical shape - so an unscoped search for the last
# matching bullet appends the new part into the wrong list entirely.
head = re.search(r"^## The parts[ \t]*$", s, re.M)
if not head:
    s = s.rstrip() + "\n\n## The parts\n\n" + entry + "\n"
else:
    body_start = head.end()
    nxt = re.search(r"^## ", s[body_start:], re.M)
    body_end = body_start + (nxt.start() if nxt else len(s) - body_start)
    section = s[body_start:body_end]
    bullets = list(re.finditer(r"^- `[^`]+/` - .*$", section, re.M))
    if bullets:
        at = body_start + bullets[-1].end()
        s = s[:at] + "\n" + entry + s[at:]
    else:
        s = s[:body_start] + "\n\n" + entry + "\n" + s[body_start:].lstrip("\n")
p.write_text(s)
PYEOF
fi

# The board says where each part's state lives, and that is the question it
# exists to answer. Seeded from a template it named two example parts, so any
# product whose parts are not called web and api got a board pointing at two
# files that do not exist - while every linter rule passed, because each file
# was individually fine. Appended here for the same reason as AGENTS.md above:
# so it cannot be left to whoever ran the script to remember.
BOARD="$ROOT/blueprint/orchestration.md"
if [ -f "$BOARD" ] && ! grep -q "^    blueprint/status/$PART\.md$" "$BOARD"; then
  python3 - "$BOARD" "$PART" <<'PYEOF'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); part = sys.argv[2]
s = p.read_text()
entry = f"    blueprint/status/{part}.md"

# Scope strictly to the section that lists them. An indented
# `blueprint/status/...` line also appears in the worked example further down,
# and appending there would file the part inside a code sample rather than the
# list a session actually reads.
head = re.search(r"^## Where each part's state lives[ \t]*$", s, re.M)
if head:
    body_start = head.end()
    nxt = re.search(r"^## ", s[body_start:], re.M)
    body_end = body_start + (nxt.start() if nxt else len(s) - body_start)
    section = s[body_start:body_end]
    entries = list(re.finditer(r"^    blueprint/status/[^\n]+\.md$", section, re.M))
    placeholder = re.search(r"^    \(none yet[^\n]*\)$", section, re.M)
    if entries:
        at = body_start + entries[-1].end()
        s = s[:at] + "\n" + entry + s[at:]
    elif placeholder:
        s = s[:body_start + placeholder.start()] + entry + s[body_start + placeholder.end():]
    p.write_text(s)
PYEOF
fi
if [ -f "$BOARD" ]; then
  grep -q "^    blueprint/status/$PART\.md$" "$BOARD" \
    || { echo "seed-part.sh: failed to list '$PART' in $BOARD" >&2; exit 1; }
fi

# The part's live state, at the PRODUCT root - never inside the part.
mkdir -p "$ROOT/blueprint/status"
if [ ! -e "$ROOT/blueprint/status/$PART.md" ]; then
  cat > "$ROOT/blueprint/status/$PART.md" <<STATUS
# $PART

**State:** idle
**Item:** -
**Blocked on:** -
**Review packet:** -
**Updated:** $(date +%Y-%m-%d)

> This part writes only this file. Nothing else writes it, which is what makes
> concurrent sessions safe.
>
> **Every field has a writer** - see the table in \`../orchestration.md\`. In
> particular, a part waiting on another part writes it in **Blocked on:**;
> \`orchestrate\` detects deadlock and stale blocks by reading that field, and can
> see nothing that was only said in a conversation.
STATUS
fi

if [ -z "$QUIET" ]; then
  echo "Added part '$PART' to $ROOT"
  echo
  echo "  $PART_PATH/                  the part - its own AGENTS.md, blueprint/ and loop"
  echo "  $PART_PATH/.claude/skills/   $(ls "$DIR/.claude/skills" 2>/dev/null | wc -l | tr -d ' ') skills, the same set every part gets"
  echo "  blueprint/status/$PART.md    its live state, at the PRODUCT root - never inside the part"
  [ "$UP" != ".." ] && echo "  Product root: $UP           because the part is $DEPTH levels down"
  echo

  # Report what was actually done, never what the happy path would have done.
  # This said "Listed in the product root's AGENTS.md and on the board"
  # unconditionally, while both writes are guarded by the file existing - so
  # seeding a part into a root that had neither printed a claim about a
  # mechanism that was not there. Found by adopting a repo that was already
  # multi-part before the workflow was installed.
  missing=""
  [ -f "$ROOT/AGENTS.md" ] \
    && echo "Listed in the product root's AGENTS.md." \
    || missing="$missing AGENTS.md"
  [ -f "$ROOT/blueprint/orchestration.md" ] \
    && echo "Listed on the board." \
    || missing="$missing blueprint/orchestration.md"

  if [ -n "$missing" ]; then
    echo
    echo "The product root is not seeded yet - missing:$missing"
    echo "  Nothing lists this part, so 'orchestrate' cannot see it and a session"
    echo "  opening the root will not know it exists. Seed the root, then re-run"
    echo "  this for each part:"
    echo
    echo "      lib/seed-product-root.sh $ROOT $PART"
  fi
  echo
  echo "Open $PART_PATH/ to work in it. The contract is shared - change it through 'orchestrate', not here."
fi
