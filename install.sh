#!/usr/bin/env bash
# Install the workflow into a project that already exists.
#
# Copies every skill into both adapter directories, and the template files that
# are not already there. Files you own - the plans, the specs, dev-notes - are
# never overwritten, with or without --force.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$PWD"
FORCE=0

usage() {
  cat <<'USAGE'
install.sh - add the workflow to an existing project

Usage:
  install.sh [--target DIR] [--force]

  --target DIR   Where to install (default: the current directory)
  --force        Replace skill files that were edited locally.
                 Never touches files you own - plans, specs, dev-notes.
  --skills-only  Install the skills and nothing else. For the product root of a
                 multi-part project, which needs every skill available but has
                 no build loop of its own - no build-plan, no current-work.
                 Detected automatically: a directory with the board and no
                 'Part:' in its AGENTS.md is a product root, and this is implied.
  --help         This
USAGE
}

SKILLS_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:?--target needs a directory}"; shift 2 ;;
    --force)  FORCE=1; shift ;;
    --skills-only) SKILLS_ONLY=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[ -d "$TARGET" ] || { echo "No such directory: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

# The product root of a multi-part project takes the skills and nothing else -
# no code is built there and there is no build loop. README documents
# --skills-only for it, but a flag you have to remember is not a guard: run
# without it and the root got a fundamentals.md it has no use for, and six
# AGENTS.md sections were reported as legacy drift because they were compared
# against the *part* template. Both symptoms were one missing question.
#
# A product root has the board and declares no `Part:`; a part declares both
# `Part:` and `Product root:`. That is the difference, so detect it rather than
# asking the user to.
PRODUCT_ROOT=0
if [ -f "$TARGET/blueprint/orchestration.md" ] \
   && ! grep -q '^- Part: ' "$TARGET/AGENTS.md" 2>/dev/null; then
  PRODUCT_ROOT=1
  if [ "$SKILLS_ONLY" -eq 0 ]; then
    SKILLS_ONLY=1
    DETECTED_ROOT=1
  fi
fi
DETECTED_ROOT="${DETECTED_ROOT:-0}"

# Was the workflow already here? Decided before anything is written, because
# every counter below changes as a side effect of writing. A first install and an
# upgrade need different closing advice, and inferring it afterwards from what
# was written gets it backwards: on a first install every pack-owned file is
# "new", which looks exactly like nothing needing an update.
HAD_WORKFLOW=0
[ -d "$TARGET/.claude/skills" ] && HAD_WORKFLOW=1

# --- skills: always fanned out to both adapters from the one source ---
skill_count=0
replaced_names=""
for adapter in .claude .agents; do
  for src in "$HERE"/skills/*.md; do
    name="$(basename "$src" .md)"
    dest="$TARGET/$adapter/skills/$name/SKILL.md"
    # Skills are pack-owned and always overwritten. `skills/` is the one source
    # and install fans it out - editing an installed copy is editing a generated
    # artifact, which the pack says plainly ("only ever one copy to edit").
    #
    # This used to keep any skill whose content differed, on the assumption that
    # a difference meant a local edit. It usually means the opposite: the pack
    # moved on. So a plain re-install upgraded nothing, and picking up new skills
    # required knowing to pass --force, whose own help calls it a way to replace
    # *edited* files. A stale skill is invisible and behaves like a current one,
    # which is the worst shape available.
    #
    # A skill under a name this pack does not have is the user's and is never
    # touched here - it is not in skills/, so this loop never reaches it.
    if [ -e "$dest" ] && ! cmp -s "$src" "$dest"; then
      case " $replaced_names " in
        *" $name "*) ;;
        *) replaced_names="$replaced_names $name" ;;
      esac
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    skill_count=$((skill_count + 1))
  done
done

# --- opencode commands: a thin `/name` wrapper per skill ---
#
# opencode discovers the skills above (it searches .claude/skills and
# .agents/skills), but skills there are invoked by the model matching a
# description - there is no `/name` to type, the way Claude Code exposes one.
# This pack's entire documented UX is "run `spec`", so without these a user
# types `/spec`, gets nothing, and reasonably concludes the skills did not load.
#
# These are wrappers, not copies: the skill body stays the single source. Format
# is opencode's own (.opencode/command/<name>.md, frontmatter + prompt body,
# $ARGUMENTS for what the user typed).
#
# Wrappers are generated from `skills/`, so they are pack-owned and always
# rewritten - the same rule as the skills themselves, for the same reason. This
# used to skip any wrapper that already existed unless --force, which meant a
# skill's description could change, the installed skill would take the new one,
# and the wrapper would keep the old. In opencode the wrapper's description is
# what the command menu shows and what the model matches a request against, so
# the stale copy is the visible one.
command_count=0
replaced_commands=""
for src in "$HERE"/skills/*.md; do
  name="$(basename "$src" .md)"
  dest="$TARGET/.opencode/command/$name.md"
  # First sentence only. Split on ". " rather than "." so filenames in the text
  # (current-work.md, project-plan.md) do not truncate it mid-phrase.
  desc="$(sed -n 's/^description:[[:space:]]*"\{0,1\}//p' "$src" | head -1 \
          | sed 's/\. .*/./' | sed 's/"//g')"
  # A first sentence can still run long. Trim on a word boundary rather than
  # mid-word, so the command menu stays readable.
  if [ "${#desc}" -gt 150 ]; then
    desc="$(printf '%s' "$desc" | cut -c1-150 | sed 's/[ ,-]*[^ ]*$//')..."
  fi
  # The modes a skill declares in its `## Input` table. Rule 15 makes sure they
  # are named in the skill's own description - which is what Claude Code matches
  # on - but the wrapper keeps only the first sentence, so no mode ever survived
  # into it. In opencode the wrapper is what the command menu shows and what the
  # model matches a request against, so every mode was invisible there:
  # `/ideate --rescope` worked, because $ARGUMENTS reaches the skill, but nobody
  # could discover it. Naming them in the body costs one line and no menu space.
  modes="$(sed -n '/^## Input/,/^## [^I]/p' "$src" | grep -oE '^\| `[^`]+`' \
           | sed 's/^| //; s/`//g' | grep -E '^-|^[a-z]' | tr '\n' ' ' || true)"
  mkdir -p "$(dirname "$dest")"
  # Generated beside the target and compared, so a wrapper that changed can be
  # named in the report rather than replaced silently.
  tmp="$dest.tmp.$$"
  cat > "$tmp" <<EOF
---
description: $desc
---

Use the \`$name\` skill from this project's workflow, following its steps in
order and stopping at every gate it defines. Read its \`## Before you start\`
section first and report anything missing rather than working around it.
EOF
  if [ -n "$modes" ]; then
    cat >> "$tmp" <<EOF

Modes this skill declares: $modes- see its \`## Input\` table for what each does.
EOF
  fi
  cat >> "$tmp" <<EOF

\$ARGUMENTS
EOF
  if [ -e "$dest" ] && ! cmp -s "$tmp" "$dest"; then
    replaced_commands="$replaced_commands $name"
  fi
  mv -f "$tmp" "$dest"
  command_count=$((command_count + 1))
done

# Where is this being installed? A plain install is a single-part project and
# gets everything. The two multi-part shapes each have files they must NOT have,
# and writing one is not harmless - it is silently wrong:
#
#   - In a part, `blueprint/` means *that part's* blueprint, so a stub
#     project-plan.md there is what an unqualified path resolves to instead of
#     the real product plan one level up. lib/seed-part.sh deletes it for exactly
#     that reason, and a re-install used to put it back.
#   - At a product root, the build loop is per-part. A build-plan.md or
#     current-work.md there is a second answer to a question that already has one.
#
# This matters most on an upgrade - re-running install.sh over a multi-part
# product to pick up new skills is the normal way to do that.
IS_PART=0
IS_PRODUCT_ROOT=0
[ -f "$TARGET/AGENTS.md" ] && grep -q '^- Part: ' "$TARGET/AGENTS.md" && IS_PART=1
[ -f "$TARGET/blueprint/orchestration.md" ] && IS_PRODUCT_ROOT=1

# --- template: only ever written when absent. These become yours on first write. ---
template_count=0
refreshed=0
if [ "$SKILLS_ONLY" -eq 0 ]; then
  while IFS= read -r src; do
    rel="${src#"$HERE"/template/}"
    case "$rel" in
      # The coordination board belongs at the product root of a multi-part
      # project, never inside a part. new-project.sh --parts places it.
      blueprint/orchestration.md) continue ;;
      # template/product/ is the product root's own AGENTS.md and CLAUDE.md.
      # Also placed by new-project.sh --parts, and meaningless in a part.
      product/*) continue ;;
      # The product plan lives at the root and is read from a part as
      # `../blueprint/project-plan.md`.
      blueprint/project-plan.md)
        [ "$IS_PART" -eq 1 ] && continue ;;
      # The build loop belongs to a part, never to the product root.
      blueprint/build-plan.md|blueprint/context/current-work.md|\
      blueprint/context/findings.md|blueprint/context/coding-standards.md|\
      blueprint/context/project-overview.md|blueprint/context/needs-you.md|\
      blueprint/history/*)
        [ "$IS_PRODUCT_ROOT" -eq 1 ] && continue ;;
    esac
    dest="$TARGET/$rel"

    # Pack-owned files are refreshed on every install. Everything else is
    # written once and never touched again.
    #
    # Without this, a template file froze at install time forever: a project set
    # up months ago still had a findings.md stub naming skills that no longer
    # exist, an 864-line blueprint/README.md describing a workflow that had been
    # replaced, and a CLAUDE.md importing a file nothing writes. `setup` was
    # correcting all of it by hand - 1741 deleted lines of work the installer
    # should have done.
    #
    # A file is only listed here if the project never has a reason to edit it.
    # Anything holding project content - the plans, the standards, the state
    # files, AGENTS.md - is the user's and is never overwritten, even when the
    # template moves on.
    case "$rel" in
      blueprint/context/fundamentals.md|\
      blueprint/history/*/README.md)
        if [ -e "$dest" ]; then
          cmp -s "$src" "$dest" && continue
          cp "$src" "$dest"
          refreshed=$((refreshed + 1))
        else
          # Writing it for the first time is not refreshing it - counting it as
          # one made a first install look like an upgrade.
          mkdir -p "$(dirname "$dest")"
          cp "$src" "$dest"
          template_count=$((template_count + 1))
        fi
        continue ;;
    esac

    if [ -e "$dest" ]; then continue; fi
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    template_count=$((template_count + 1))
  done < <(find "$HERE/template" -type f)
fi

# --- prune skills this pack used to have -------------------------------------
#
# Installing never removed anything, so a project set up long ago carried every
# skill it was ever given. One had 42 installed and 16 were from a predecessor
# pack - `audit`, `brief`, `onboard`, `techstack` and the rest - all loaded by
# the agent, all contradicting the current workflow. check.sh rule 5 catches a
# stale *reference* inside this repo; nothing caught stale *files* inside a
# project, which is the copy anyone actually runs against.
#
# Only names in lib/retired-names are removed. Anything else unrecognised is the
# user's own skill and is reported, never deleted - a `run-<project>` skill is a
# real example, and deleting it would be destroying their work to tidy ours.
pruned_names=""
unknown=""
retired_file="$HERE/lib/retired-names"
if [ -f "$retired_file" ]; then
  retired_names="$(grep -v '^#' "$retired_file" | grep -v '^[[:space:]]*$' | tr '\n' ' ')"
  for adapter in "$TARGET/.claude/skills" "$TARGET/.agents/skills"; do
    [ -d "$adapter" ] || continue
    for dir in "$adapter"/*/; do
      [ -d "$dir" ] || continue
      name="$(basename "$dir")"
      [ -f "$HERE/skills/$name.md" ] && continue
      case " $retired_names " in
        *" $name "*)
          rm -rf "$dir"
          rm -f "$TARGET/.opencode/command/$name.md"
          # Count names, not directories. A skill can exist in one adapter and
          # not the other - a hand-written Claude Code skill usually does - so
          # halving a directory count reports the wrong number.
          case " $pruned_names " in *" $name "*) ;; *) pruned_names="$pruned_names $name" ;; esac ;;
        *)
          case " $unknown " in *" $name "*) ;; *) unknown="$unknown $name" ;; esac ;;
      esac
    done
  done
fi

# --- legacy shapes: report, never rewrite ------------------------------------
#
# A project installed before a structural change carries the old shape, and the
# installer cannot fix it: these are project-owned files, and overwriting one is
# the defect the ownership boundary above exists to prevent. Worse, a merge here
# needs judgement a script does not have - the first real `setup` run corrected
# four wrong rules while restructuring, and a script stripping "the duplicated
# part" would have deleted those corrections along with the duplication.
#
# So: name it, name who fixes it, and touch nothing.
legacy=""
cs="$TARGET/blueprint/context/coding-standards.md"
if [ -f "$cs" ] && grep -qE '^#+ Part 1' "$cs"; then
  legacy="$legacy\n  - blueprint/context/coding-standards.md still has its own \"Part 1\".\n    The fundamentals now live in fundamentals.md, which the pack refreshes.\n    Run 'setup' to reconcile: it keeps what this project genuinely does\n    differently and drops what is now duplicated."
fi
# AGENTS.md is project-owned - it holds Commands and Environments, which are this
# project's - so it is never overwritten, and a section added to the template
# later never reaches a project that already exists. One had no Environments
# table at all while nine skills read it, including `migrate`, whose rule is that
# an environment *not* in the table is treated as holding real data. With no
# table, that is undefined rather than safe.
#
# Compared by heading, and reported rather than inserted: a project may have
# deleted a section deliberately, and this file is not ours to edit.
# A product root's AGENTS.md comes from template/product/AGENTS.md and has
# deliberately different sections. Comparing it against the part template
# reported six sections missing and told the user to run `setup` over a file
# that was exactly right.
AGENTS_TEMPLATE="$HERE/template/AGENTS.md"
[ "$PRODUCT_ROOT" -eq 1 ] && AGENTS_TEMPLATE="$HERE/template/product/AGENTS.md"
if [ -f "$TARGET/AGENTS.md" ] && [ -f "$AGENTS_TEMPLATE" ]; then
  missing_sections=""
  while IFS= read -r heading; do
    grep -qxF "$heading" "$TARGET/AGENTS.md" || missing_sections="$missing_sections${missing_sections:+, }${heading#\#\# }"
  done < <(grep '^## ' "$AGENTS_TEMPLATE")
  [ -n "$missing_sections" ] && legacy="$legacy\n  - AGENTS.md has no: $missing_sections\n    Sections the workflow added after this project was set up. It is your file,\n    so nothing here writes them - 'setup' fills them in from the real project."
fi

# The board's part list was copied verbatim from the template until 2026-09-07,
# so any product seeded before then names `web.md` and `api.md` whatever its
# parts are really called - the coordination file wrong about the one thing it
# exists to record. It is project-owned state (it holds the frozen contract
# line), so this reports and never rewrites, like every other legacy shape here.
BOARD="$TARGET/blueprint/orchestration.md"
if [ -f "$BOARD" ] && [ -d "$TARGET/blueprint/status" ]; then
  board_wrong=""
  for f in "$TARGET"/blueprint/status/*.md; do
    [ -e "$f" ] || continue
    n=$(basename "$f")
    grep -q "^    blueprint/status/$n\$" "$BOARD" || board_wrong="$board_wrong $n"
  done
  board_phantom=""
  while read -r n; do
    [ -n "$n" ] && [ ! -e "$TARGET/blueprint/status/$n" ] && board_phantom="$board_phantom $n"
  done < <(sed -n 's|^    blueprint/status/\(.*\.md\)$|\1|p' "$BOARD")
  if [ -n "$board_wrong" ] || [ -n "$board_phantom" ]; then
    legacy="$legacy\n  - blueprint/orchestration.md lists the wrong parts."
    [ -n "$board_phantom" ] && legacy="$legacy\n    Names files that do not exist:$board_phantom"
    [ -n "$board_wrong" ]   && legacy="$legacy\n    Does not name real parts:$board_wrong"
    legacy="$legacy\n    It was seeded from a template that hard-coded web.md and api.md. The\n    board is yours - it holds the contract line - so nothing here rewrites it.\n    Fix the list under 'Where each part's state lives' to match blueprint/status/."
  fi
fi

# CLAUDE.md is yours and is never rewritten here, so a project created before a
# context file was added keeps an import list that predates it - the file lands
# in blueprint/context/ and nothing ever loads it. That is the pack's own worst
# defect class arriving by upgrade: a file with readers and nothing that puts it
# in context. Reported against what the current template declares auto-loaded.
if [ -f "$TARGET/CLAUDE.md" ] && [ -f "$HERE/template/AGENTS.md" ]; then
  unimported=""
  while read -r ctx; do
    [ -n "$ctx" ] || continue
    # only mention a file the project actually has - otherwise this is noise
    [ -f "$TARGET/$ctx" ] || continue
    grep -qF "@$ctx" "$TARGET/CLAUDE.md" || unimported="$unimported ${ctx##*/}"
  done < <(awk '/These are already loaded/{f=1} /These are not loaded/{f=0} f' \
             "$HERE/template/AGENTS.md" | grep -oE 'blueprint/context/[a-z-]+\.md' | sort -u)
  if [ -n "$unimported" ]; then
    legacy="$legacy\n  - CLAUDE.md does not load:$unimported"
    legacy="$legacy\n    These exist here and AGENTS.md lists them as always-loaded context, but"
    legacy="$legacy\n    CLAUDE.md's import list predates them, so no session actually gets them."
    legacy="$legacy\n    CLAUDE.md is yours, so nothing here edits it - add a line per file:"
    for m in $unimported; do legacy="$legacy\n        @blueprint/context/$m"; done
  fi
fi

if [ -d "$TARGET/blueprint/.state" ]; then
  legacy="$legacy\n  - blueprint/.state/ is from an older pack. Nothing here reads it.\n    Safe to delete once you are happy nothing of yours depends on it."
fi

echo "Installed into $TARGET"
echo "  $skill_count skill file(s) across 2 adapters"
[ -n "$replaced_names" ] && {
  echo "  updated from a different version:$replaced_names"
  echo "    If you had edited one of these, it is in git - recover with git diff."
}
[ -n "$pruned_names" ] && echo "  retired skill(s) removed:$pruned_names"
[ -n "$unknown" ] && {
  echo "  kept, not from this pack:$unknown"
  echo "    Your own skills, or from a version this pack does not know about."
  echo "    Nothing here removes them - delete any you no longer want."
}
echo "  $command_count opencode command wrapper(s) in .opencode/command/"
[ -n "$replaced_commands" ] && \
  echo "    rewritten from a different version:$replaced_commands"
if [ "$SKILLS_ONLY" -eq 1 ]; then
  if [ "$DETECTED_ROOT" -eq 1 ]; then
    echo "  product root detected - skills only, no build-loop files"
    echo "  (it has the board and declares no 'Part:'; --skills-only was implied)"
  else
    echo "  skills only - no template files written"
  fi
else
  echo "  $template_count template file(s) written (existing ones left alone)"
  [ "$refreshed" -gt 0 ] && echo "  $refreshed pack-owned file(s) refreshed"
fi

# Legacy findings print in BOTH modes. They used to sit inside the branch above,
# so `--skills-only` silently suppressed them - and the product root, which is
# the one place --skills-only is the documented mode, is also the only place the
# board's part list can be wrong. The report that existed for that case could
# never reach it.
[ -n "$legacy" ] && { echo; echo "From an older version of this pack:"; printf '%b\n' "$legacy"; }

echo
# "Run setup" is right for a first install and wrong for an upgrade: a project
# already part-way through the loop has been tuned, and `setup` would re-tune
# it. Anything replaced here means the pack moved on, not that the project is
# new. `progress` is the skill that says where an existing project stands.
if [ "$HAD_WORKFLOW" -eq 1 ]; then
  echo "This project already had the workflow. Nothing of yours was changed -"
  echo "run 'progress' to see where it stands, or 'prepare' for anything waiting"
  echo "on you. Run 'setup' only if the workflow no longer matches this repo."
else
  echo "Next: open this directory with your AI tool and run 'setup' so the workflow"
  echo "matches what is actually here."
fi
