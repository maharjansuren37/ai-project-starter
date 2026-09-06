#!/usr/bin/env bash
# Turn a directory into a part of a multi-part product.
#
# Shared by new-project.sh (creating parts from scratch) and convert-to-parts.sh
# (splitting an existing project). One copy, because the two callers producing
# subtly different parts is exactly the failure this pack keeps finding: every
# file individually valid, the mechanism between them broken.
#
# Usage: seed-part.sh <product-root> <part-name>
#
# Idempotent. Safe over a directory that already has the workflow in it -
# install.sh keeps files you own.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ROOT="${1:?seed-part.sh needs a product root}"
PART="${2:?seed-part.sh needs a part name}"

# A part name becomes a directory under the product root and is substituted into
# AGENTS.md, the board and every cross-part path. Anything with a slash escapes
# the product root entirely - `--parts '../x,api'` created a sibling of the
# project and reported success, because the caller that had this guard was
# convert-to-parts.sh and the caller that did not was new-project.sh.
#
# The guard lives here, at the one point both callers pass through, rather than
# in each of them. Two copies of a rule is how the rule drifts - which is the
# same reason this file is shared in the first place. Callers may check earlier
# for a friendlier message; none of them may be the only check.
case "$PART" in
  ""|.|..|-*|*/*|*\\*|*[[:space:]]*)
    echo "seed-part.sh: not a usable part name: '$PART'" >&2
    echo "  A part is a single directory name - letters, digits, . _ - " >&2
    echo "  It may not contain a slash, start with '-', or be '.' or '..'." >&2
    exit 1 ;;
esac

DIR="$ROOT/$PART"

mkdir -p "$DIR"
"$HERE/install.sh" --target "$DIR" >/dev/null

# This part's blueprint is its own; the product plan lives one level up. install.sh
# writes a stub when none is present, so remove it after rather than before.
rm -f "$DIR/blueprint/project-plan.md"

# The Part / Product root fields are read by spec, build, ship, autopilot and
# orchestrate to resolve every cross-part path. A part missing them does not fail
# loudly - each session silently resolves the board to the part's own blueprint,
# where no other part is looking. So substitution is verified, not assumed.
python3 - "$DIR/AGENTS.md" "$PART" <<'PYEOF'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); part = sys.argv[2]
s = p.read_text()
fields = (f"- Part: {part}\n"
          "- Product root: ..\n\n"
          "**`blueprint/` means this part's blueprint.** The shared product plan is at\n"
          "`../blueprint/project-plan.md` and the coordination board at\n"
          "`../blueprint/orchestration.md`. Read the board before starting work.")
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
grep -q '^- Product root: \.\.$' "$DIR/AGENTS.md" \
  || { echo "seed-part.sh: failed to write 'Product root: ..' into $DIR/AGENTS.md" >&2; exit 1; }

# The product root's AGENTS.md lists the parts, and it is what a session opening
# the root reads first. Adding a part without listing it there leaves the root
# describing a product that no longer exists - so this is appended here rather
# than left to whoever ran the script to remember.
if [ -f "$ROOT/AGENTS.md" ] && ! grep -q '^- `'"$PART"'/`' "$ROOT/AGENTS.md"; then
  python3 - "$ROOT/AGENTS.md" "$PART" <<'PYEOF'
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
