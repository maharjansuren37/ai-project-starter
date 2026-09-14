#!/usr/bin/env bash
# Split a single-part project into a multi-part product.
#
# This is the path the docs call the better one: start single, and convert once
# `architect` has decided the boundary - because you know more then than at the
# start. It existed as a recommendation with no mechanism behind it until now.
#
# What it does: moves the entire existing project into one part directory, lifts
# the product-level files back to the root, seeds the board and the other parts,
# and gives the product root its own skills and instructions.
#
# It moves everything. That is why it insists on a clean git tree - the whole
# operation must be one reviewable diff you can throw away.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
convert-to-parts.sh - split a single-part project into parts

Usage:
  convert-to-parts.sh --parts A,B --existing A [--target DIR] [--allow-dirty]

  --parts A,B    Every part the product will have, including the one the
                 current project becomes. Top-level directory names: what
                 moves into --existing is decided by a top-level name, so a
                 nested part (apps/web) is seeded afterwards with
                 lib/seed-part.sh instead - docs/multi-part.md.
  --existing A   Which of those the current project becomes. Everything here
                 now - source, config, blueprint, dev-notes - moves into it.
                 Must be one of --parts.
  --target DIR   The project to convert (default: the current directory)
  --allow-dirty  Proceed without git, or with uncommitted changes. This moves
                 every file in the project; without git there is no undo.
  --help         This

Afterwards the product root holds the shared plan, the coordination board, the
contracts directory and its own copy of the skills. Each part holds its own
build loop. Nothing is deleted - the existing project is moved, not rebuilt.
USAGE
}

TARGET="$PWD"
PARTS=""
EXISTING=""
ALLOW_DIRTY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --parts)    PARTS="${2:?--parts needs a comma-separated list}"; shift 2 ;;
    --existing) EXISTING="${2:?--existing needs a part name}"; shift 2 ;;
    --target)   TARGET="${2:?--target needs a directory}"; shift 2 ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    --help|-h)  usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[ -n "$PARTS" ]    || { echo "--parts is required." >&2; usage >&2; exit 1; }
[ -n "$EXISTING" ] || { echo "--existing is required - say which part this project becomes." >&2; usage >&2; exit 1; }
[ -d "$TARGET" ]   || { echo "No such directory: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

# --- parse and validate the part list ---
clean_parts=()
IFS=',' read -ra PART_LIST <<< "$PARTS"
for p in "${PART_LIST[@]}"; do
  p="$(echo "$p" | tr -d '[:space:]')"
  [ -n "$p" ] || continue
  case "$p" in
    # lib/seed-part.sh takes a nested path and this does not: everything in the
    # project moves into --existing, and what moves is decided by comparing
    # top-level directory names. Say that, rather than refusing a shape the
    # guide two files away calls supported and naming no route that takes it.
    */*)
      echo "Not a usable part name here: $p" >&2
      echo "convert-to-parts.sh creates parts as top-level directories." >&2
      echo "Convert with top-level names, then add a nested part with" >&2
      echo "lib/seed-part.sh - see docs/multi-part.md." >&2
      exit 1 ;;
    .|..) echo "Not a usable part name: $p" >&2; exit 1 ;;
  esac
  clean_parts+=("$p")
done
[ "${#clean_parts[@]}" -ge 2 ] || { echo "A multi-part product needs at least two parts." >&2; exit 1; }

found=0
for p in "${clean_parts[@]}"; do [ "$p" = "$EXISTING" ] && found=1; done
[ "$found" -eq 1 ] || {
  echo "--existing '$EXISTING' is not in --parts ($PARTS)." >&2
  echo "The current project has to become one of the parts." >&2
  exit 1
}

# --- refuse anything that is not a single-part project of this workflow ---
[ -f "$TARGET/AGENTS.md" ] && [ -d "$TARGET/blueprint" ] || {
  echo "$TARGET does not look like a project built with this workflow." >&2
  echo "Expected AGENTS.md and blueprint/. Use install.sh to add the workflow first." >&2
  exit 1
}

if [ -e "$TARGET/blueprint/orchestration.md" ] || grep -q '^- Part: ' "$TARGET/AGENTS.md" 2>/dev/null; then
  echo "$TARGET is already a multi-part project." >&2
  echo "To add one more part to it, run: lib/seed-part.sh $TARGET <name>" >&2
  exit 1
fi

for p in "${clean_parts[@]}"; do
  [ -e "$TARGET/$p" ] && { echo "$TARGET/$p already exists - pick part names that do not collide." >&2; exit 1; }
done

# --- git safety. This moves every file in the project. ---
if [ "$ALLOW_DIRTY" -eq 0 ]; then
  git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "$TARGET is not a git repository." >&2
    echo "This moves every file in the project and there would be no way back." >&2
    echo "Run 'git init' and commit first, or pass --allow-dirty to accept that." >&2
    exit 1
  }
  [ -z "$(git -C "$TARGET" status --porcelain)" ] || {
    echo "$TARGET has uncommitted changes." >&2
    echo "Commit or stash first - the conversion should be one reviewable diff," >&2
    echo "not a move tangled up with work in progress." >&2
    echo "Or pass --allow-dirty." >&2
    exit 1
  }
fi

# --- move the existing project into its part ---
# Everything goes except the repository itself, the ignore rules, and the
# product-facing README. The product-level blueprint files are lifted back out
# afterwards rather than held aside here, so a failure midway leaves one
# recognisable state instead of a half-sorted root.
mkdir -p "$TARGET/$EXISTING"
moved=0
shopt -s dotglob nullglob
for entry in "$TARGET"/*; do
  base="$(basename "$entry")"
  case "$base" in
    .git|.gitignore|README.md) continue ;;
  esac
  skip=0
  for p in "${clean_parts[@]}"; do [ "$base" = "$p" ] && skip=1; done
  [ "$skip" -eq 1 ] && continue
  mv "$entry" "$TARGET/$EXISTING/"
  moved=$((moved + 1))
done
shopt -u dotglob nullglob

# --- lift the product-level files back to the root ---
# The plan is the product's - `new-project.sh --parts` keeps no copy in a part.
mkdir -p "$TARGET/blueprint/context"
[ -f "$TARGET/$EXISTING/blueprint/project-plan.md" ] &&
  mv "$TARGET/$EXISTING/blueprint/project-plan.md" "$TARGET/blueprint/project-plan.md"
# How to communicate is a product-wide decision, and both levels need it, so this
# one is copied rather than moved - and the project's tuned version wins over the
# template that seed-product-root.sh would otherwise write.
[ -f "$TARGET/$EXISTING/blueprint/context/ai-interaction.md" ] &&
  cp "$TARGET/$EXISTING/blueprint/context/ai-interaction.md" "$TARGET/blueprint/context/ai-interaction.md"

# --- seed the product root and every part ---
# Same two helpers new-project.sh --parts uses, so a converted product and a
# created one are the same shape. Neither overwrites a file already present.
"$HERE/lib/seed-product-root.sh" "$TARGET" "${clean_parts[@]}"
for p in "${clean_parts[@]}"; do
  "$HERE/lib/seed-part.sh" "$TARGET" "$p" --quiet
done

# --- repair the ignore rules if this project predates the skills fix ---
# `build/` matches at any depth, and one of the skills is called `build`. A
# project created before that was fixed has been quietly failing to commit it,
# and the conversion is about to create more copies of the same directory.
gitignore_fixed=0
if [ -f "$TARGET/.gitignore" ] && grep -qE '^(build|dist|out)/$' "$TARGET/.gitignore" \
   && ! grep -q 'skills/build/' "$TARGET/.gitignore"; then
  cat >> "$TARGET/.gitignore" <<'IGNORE'

# ...but never the workflow's own skills. `build/` above matches at any depth,
# and one of the skills is called `build` - so without these the single most
# important skill in the pack is silently absent from every clone. Re-including
# the directory is required: git will not re-include a file whose parent
# directory is excluded.
!**/skills/build/
!**/skills/build/**
!**/skills/dist/
!**/skills/dist/**
!**/skills/out/
!**/skills/out/**
IGNORE
  gitignore_fixed=1
fi

# --- what moved into $EXISTING that may belong to more than one part ---
#
# Everything part-local moved into --existing and the new parts got empty stubs.
# That is right for most of it - a part's findings and current work are its own.
# It is wrong for anything that described the *product* before there were parts:
# the build plan holds product features that each need work in both, and a
# needs-you line about a toolchain belongs to whichever part uses it.
#
# This is reported, never split: telling a product feature apart from a
# front-end-only one is judgement, and the plans are the user's files. Same rule
# as install.sh - name it, and name who fixes it.
split_report=""
# `grep -c` prints 0 and exits 1 when it matches nothing, so `|| echo 0` appended
# a second 0 and every `-gt` below died with "integer expected" - three of them,
# on stderr, immediately after this script moved every file in the project. It
# looked exactly like a crash mid-move. The assignment carries grep's own exit
# status, so `|| _x=0` covers both no-match and a file that is not there.
_items=$(grep -c '^- \[ \]' "$TARGET/$EXISTING/blueprint/build-plan.md" 2>/dev/null) || _items=0
if [ "$_items" -gt 0 ]; then
  split_report="$split_report
  - $EXISTING/blueprint/build-plan.md has $_items unchecked item(s), and every
    other part's is empty. Items written before the split describe the product,
    so one of them usually needs work in more than one part. Nothing here can
    tell those apart - 'spec' reads whichever part you run it in, and an empty
    plan there reports 'nothing is queued'. Split them per part by hand."
fi
_needs=$(grep -c '^### ' "$TARGET/$EXISTING/blueprint/context/needs-you.md" 2>/dev/null) || _needs=0
if [ "$_needs" -gt 0 ]; then
  split_report="$split_report
  - $EXISTING/blueprint/context/needs-you.md has $_needs open line(s). Any that
    are about a toolchain or an account belong to the part that uses it;
    'prepare' only reads the part it is run in."
fi
_dec=$(grep -c '^## D[0-9]' "$TARGET/$EXISTING/dev-notes/decisions.md" 2>/dev/null) || _dec=0
if [ "$_dec" -gt 0 ]; then
  split_report="$split_report
  - $EXISTING/dev-notes/decisions.md has $_dec entry(ies) taken before the split.
    Any that are product-wide read as $EXISTING's private history where they are."
fi

parts_report="$(printf '  %-30s%s\n' "$EXISTING/" "the project that was here - $moved entries moved in")"
for p in "${clean_parts[@]}"; do
  [ "$p" = "$EXISTING" ] && continue
  parts_report="$parts_report"$'\n'"$(printf '  %-30s%s' "$p/" 'new and empty - scaffold it when the contract is frozen')"
done

cat <<DONE
Converted $TARGET into a multi-part product.

$parts_report
  blueprint/project-plan.md     lifted back to the root - it is the product's
  blueprint/orchestration.md    the coordination board, contract NOT FROZEN
  blueprint/status/             one live-state file per part
  contracts/                    the boundary between the parts
  AGENTS.md / CLAUDE.md         the product root's own instructions, plus its
                                own copy of the skills
$([ "$gitignore_fixed" -eq 1 ] && echo "
  .gitignore was ignoring the workflow's own 'build' skill - a rule matching at
  any depth caught .claude/skills/build/. Re-include rules appended.
")
Nothing was deleted. Review it as one diff:

  git -C $TARGET add -A && git -C $TARGET status

$([ -n "$split_report" ] && echo "
Moved into $EXISTING/ but written before there were parts:
$split_report

  Nothing here splits these - it cannot tell a product feature from a
  front-end-only one. Do it before any part starts work.")

Then, before any part starts work:

  1. 'architect' at the product root - the boundary, and who owns the contract
  2. write the contract into contracts/
  3. 'orchestrate' to freeze it. No part works in parallel until it is frozen.
DONE
