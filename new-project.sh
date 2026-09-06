#!/usr/bin/env bash
# Create a new project directory with the whole workflow already in it.
#
# The point of creating the directory here is that there is never a moment when
# you have an AI tool open in a folder with no skills. Open it and everything -
# ideate, stack, scaffold, build, ship, host, deploy, monitor - is already there.
#
# It deliberately does NOT create a source directory. The `scaffold` skill does
# that later, once `stack` has decided what this project actually is, using the
# framework's own layout rather than one imposed here.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
new-project.sh - create a project with the workflow already installed

Usage:
  new-project.sh <name> [--in DIR] [--no-git]

  <name>      Directory to create. A bare name, a relative path, or an
              absolute path - all three work:
                new-project.sh my-app                  ./my-app
                new-project.sh projects/my-app         ./projects/my-app
                new-project.sh ~/code/my-app           /home/you/code/my-app
  --in DIR    Create it inside DIR instead of the current directory.
              Not combinable with an absolute path.
  --parts A,B Create a multi-part project: a shared product plan, a
              coordination board, and one part directory per name. Each part
              gets its own loop and its own state, so parallel sessions cannot
              collide. Omit for a single-session project - the default, and the
              right answer for most work.
  --no-git    Skip git init
  --help      This

Creates the directory, installs every skill for both adapters, seeds the
planning and dev-notes files, writes a .gitignore, and initialises git.
No source directory is created - `scaffold` does that once a stack is chosen.
USAGE
}

NAME=""
PARENT="$PWD"
PARENT_SET=0
DO_GIT=1
PARTS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --in)     PARENT="${2:?--in needs a directory}"; PARENT_SET=1; shift 2 ;;
    --parts)  PARTS="${2:?--parts needs a comma-separated list}"; shift 2 ;;
    --no-git) DO_GIT=0; shift ;;
    --help|-h) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *) [ -n "$NAME" ] && { echo "Only one name, please." >&2; exit 1; }; NAME="$1"; shift ;;
  esac
done

[ -n "$NAME" ] || { usage >&2; exit 1; }

# The name may be a bare name, a relative path, or an absolute path. Resolve all
# three to one target, rather than blindly joining onto the parent - which turns
# an absolute path into a deeply nested one and reports success.
case "$NAME" in
  /*)
    [ "$PARENT_SET" -eq 0 ] || { echo "Use either an absolute path or --in, not both." >&2; exit 1; }
    TARGET="$NAME"
    ;;
  '~'/*)
    [ "$PARENT_SET" -eq 0 ] || { echo "Use either an absolute path or --in, not both." >&2; exit 1; }
    TARGET="$HOME/${NAME#\~/}"
    ;;
  *)
    [ -d "$PARENT" ] || { echo "No such directory: $PARENT" >&2; exit 1; }
    TARGET="$(cd "$PARENT" && pwd)/$NAME"
    ;;
esac

# The parent of the target must exist. Creating a project three levels into a
# directory tree that does not exist is more likely a typo than an intention.
TARGET_PARENT="$(dirname "$TARGET")"
[ -d "$TARGET_PARENT" ] || {
  echo "No such directory: $TARGET_PARENT" >&2
  echo "Create it first, or pick a path whose parent exists." >&2
  exit 1
}
TARGET="$(cd "$TARGET_PARENT" && pwd)/$(basename "$TARGET")"

# Refuse to touch anything that already exists. Creating a project is not an
# operation that should ever merge into someone else's directory.
if [ -e "$TARGET" ]; then
  echo "Already exists: $TARGET" >&2
  echo "To add the workflow to an existing project, use install.sh instead." >&2
  exit 1
fi

mkdir -p "$TARGET"

# .gitignore is written BEFORE git init, so the very first commit cannot contain
# a real .env or a dependency directory.
cat > "$TARGET/.gitignore" <<'IGNORE'
# Secrets - never commit these
.env
.env.*
!.env.example

# ...and a local database is the same class of mistake. A file database holds
# real rows, not configuration, and a dev one fills up with real names while you
# are testing. Committed once it is in history forever - `strings` on the blob
# reads it straight back. SQLite is the default for a small project, so this is
# the common case, not an exotic one. Un-ignore a deliberately committed seed
# file if you have one.
*.db
*.db-shm
*.db-wal
*.sqlite
*.sqlite3

# Dependencies
node_modules/
.pnp
vendor/
.venv/
__pycache__/

# Build output
dist/
build/
out/
.next/
.output/
*.tsbuildinfo

# .NET, JVM, Rust, Go. These were absent, and the list above is not
# ecosystem-neutral - it covers JS, Python and Ruby only. One `dotnet build` in
# a real project staged 156 files from bin/ and obj/, while every check here
# passed: nothing reads .gitignore except git. `obj/` is .NET's restore output,
# so it is a dependency directory as much as a build one.
bin/
obj/
target/
*.user
*.class

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

# Local noise
.DS_Store
*.log
.cache/
coverage/
IGNORE

if [ -z "$PARTS" ]; then
  # Single-session project: one loop, one state. The default.
  "$HERE/install.sh" --target "$TARGET" >/dev/null
else
  # Multi-part: a shared product plan at the root, and a full loop inside each
  # part. Parts never share build state, which is what lets sessions run in
  # parallel without overwriting each other.
  #
  # Both steps are shared with convert-to-parts.sh, so a converted project and a
  # created one are the same shape. Two callers building parts slightly
  # differently is precisely the kind of seam that breaks here.
  parts_made=""
  IFS=',' read -ra PART_LIST <<< "$PARTS"
  clean_parts=()
  for part in "${PART_LIST[@]}"; do
    part="$(echo "$part" | tr -d '[:space:]')"
    [ -n "$part" ] || continue
    # Checked here so nothing is created before a bad name is reported, and
    # again in lib/seed-part.sh so no caller can be the only guard. This one
    # was missing while convert-to-parts.sh had it - a part name with a slash
    # wrote a directory outside the product root and exited 0.
    case "$part" in
      .|..|-*|*/*|*\\*)
        echo "Not a usable part name: '$part'" >&2
        echo "A part is a single directory name, not a path." >&2
        exit 1 ;;
    esac
    clean_parts+=("$part")
    parts_made="$parts_made $part"
  done
  [ "${#clean_parts[@]}" -gt 0 ] || { echo "--parts listed no usable names." >&2; exit 1; }

  "$HERE/lib/seed-product-root.sh" "$TARGET" "${clean_parts[@]}"
  for part in "${clean_parts[@]}"; do
    "$HERE/lib/seed-part.sh" "$TARGET" "$part"
  done
fi

if [ "$DO_GIT" -eq 1 ]; then
  if command -v git >/dev/null 2>&1; then
    # -b main so the branch name is this pack's decision rather than whatever
    # init.defaultBranch happens to be on the machine. Two people running this
    # script should get the same repository.
    if ! git -C "$TARGET" init --quiet -b main 2>/dev/null; then
      git -C "$TARGET" init --quiet                       # git < 2.28
      git -C "$TARGET" symbolic-ref HEAD refs/heads/main
    fi
  else
    echo "  note: git not found, skipping init"
    DO_GIT=0
  fi
fi

# The initial commit is made here, not left to the user.
#
# Without it `main` is an *unborn* branch: it does not exist until something is
# committed on it. A first `git checkout -b feat/...` then moves that unborn HEAD
# to the feature branch, the first commit lands there, and `main` silently never
# comes into being - so `ship`'s squash-merge has nothing to merge into. Whether
# the base branch exists otherwise depends on the order the user happens to do
# things, which is not a thing to leave to chance.
#
# This also makes good on the .gitignore written above: the clean first commit is
# an actual commit rather than an intention.
if [ "$DO_GIT" -eq 1 ]; then
  git -C "$TARGET" add -A
  git -C "$TARGET" -c user.useConfigOnly=false commit --quiet \
    -m "chore: start the project with the workflow installed" 2>/dev/null \
    || echo "  note: nothing committed (git identity not configured) - commit before branching"
fi

skills=$(find "$HERE/skills" -name '*.md' | wc -l | tr -d ' ')
if [ -n "$PARTS" ]; then
  cat <<PARTSDONE
Created $TARGET

  Multi-part project:$parts_made
  Each part has its own $skills skills and its own loop state, so parallel
  sessions cannot overwrite each other.

  AGENTS.md / CLAUDE.md         the product root's own instructions
  blueprint/project-plan.md     the shared product plan
  blueprint/orchestration.md    the coordination board - read it before working
  blueprint/status/             one live-state file per part
  contracts/                    the boundary between parts

The $skills skills are installed here at the root as well, because 'orchestrate',
'ideate', 'stack' and 'architect' run for the product rather than for one part.
Open this directory for those; open a part's directory to build in it.

Do the planning together and single-threaded first - idea, stack, architect, and
the contract. Only move parts into parallel work once the board says the contract
is frozen.

Next:
  cd $NAME
  open it with your AI tool, then run 'ideate' to shape what you are building.
PARTSDONE
  exit 0
fi

cat <<DONE
Created $TARGET

  $skills skills, installed for Claude Code (.claude/) and everything else (.agents/)
  blueprint/   the workflow's state - plans, specs, findings, history
  dev-notes/   decisions and status, for picking this up cold later
  .gitignore   $([ "$DO_GIT" -eq 1 ] && echo "written before git init, so the first commit is clean" || echo "written, ready for whenever this becomes a repository")
$([ "$DO_GIT" -eq 1 ] && echo "  git          initialised on 'main', with that first commit already made")

There is no source directory yet - that is deliberate. The 'scaffold' skill
creates it once 'stack' has decided what this project is.

Next:
  cd $NAME
  open it with your AI tool, then run 'ideate' to shape what you are building.
DONE
