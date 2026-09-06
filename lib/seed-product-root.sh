#!/usr/bin/env bash
# Seed the product root of a multi-part project: the shared plan, the board, the
# contracts directory, and the root's own skills and instructions.
#
# Shared by new-project.sh and convert-to-parts.sh. Never writes over a file that
# is already there, so it is safe to run against a project being converted -
# whose project-plan.md, README.md and ai-interaction.md are already the real
# ones and must survive.
#
# Usage: seed-product-root.sh <product-root> <part> [<part> ...]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ROOT="${1:?seed-product-root.sh needs a product root}"
shift
PARTS=("$@")

copy_if_absent() { [ -e "$2" ] || cp "$1" "$2"; }

mkdir -p "$ROOT/blueprint/context" "$ROOT/blueprint/status" "$ROOT/contracts" "$ROOT/dev-notes"

copy_if_absent "$HERE/template/blueprint/project-plan.md"           "$ROOT/blueprint/project-plan.md"
copy_if_absent "$HERE/template/blueprint/orchestration.md"          "$ROOT/blueprint/orchestration.md"
copy_if_absent "$HERE/template/blueprint/context/ai-interaction.md" "$ROOT/blueprint/context/ai-interaction.md"
copy_if_absent "$HERE/template/README.md"                           "$ROOT/README.md"
copy_if_absent "$HERE/template/dev-notes/decisions.md"              "$ROOT/dev-notes/decisions.md"
copy_if_absent "$HERE/template/dev-notes/status.md"                 "$ROOT/dev-notes/status.md"

if [ ! -e "$ROOT/contracts/README.md" ]; then
  cat > "$ROOT/contracts/README.md" <<'CONTRACT'
# Contracts

The boundary between the parts. **Owned by the part that can break it** - usually
the backend, because it is the one that defines the shape.

A generated contract (OpenAPI, a schema) is the single source of truth: the
owning part emits it, the others generate their clients from it, and generation
runs as part of the build rather than by hand.

**It lives here, at the product root, not inside the owning part.** A file inside
`api/` reads as `api`'s private business to everyone working in `web/`, when it
is the one thing both are bound by.

## Who reads this

- `architect` decides the format, who owns it, and the filename - and records the
  regeneration command in `AGENTS.md`
- `scaffold` creates the file and wires generation into the build
- `ci` regenerates it on every push and fails on a difference
- `integrate` does the same before anything deploys
- `orchestrate` names the frozen version on the board

**So an empty `contracts/` is not a neutral state** - it means those five checks
have nothing to check. Say so rather than passing them.

**Freezing matters more than the format.** Parallel work against an unfrozen
contract means each part invents its own assumptions and none of them find out
until integration. `orchestrate` will not move parts into parallel work until the
board's contract line says frozen.
CONTRACT
fi

# The product root needs the skills too. `orchestrate` reads the board and every
# part; `ideate`, `stack` and `architect` write the product plan that lives here.
# Without a copy here there is nowhere to run them from - and running them from
# inside a part resolves `blueprint/` to that part's own, where the board is not.
"$HERE/install.sh" --target "$ROOT" --skills-only >/dev/null
copy_if_absent "$HERE/template/product/CLAUDE.md" "$ROOT/CLAUDE.md"

if [ ! -e "$ROOT/AGENTS.md" ]; then
  python3 - "$HERE/template/product/AGENTS.md" "$ROOT/AGENTS.md" "${PARTS[@]}" <<'PYEOF'
import sys, pathlib
src, dest, parts = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3:]
listing = "\n".join(f"- `{p}/` - <what this part is>" for p in parts)
dest.write_text(src.read_text().replace("<!-- PARTS -->", listing, 1))
PYEOF
fi
