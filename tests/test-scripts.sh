#!/usr/bin/env bash
# What the scripts actually do when run, rather than what they read like.
#
# Every defect these cover was found by running a command and comparing the
# result against what was claimed - never by reading.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Derived, never hardcoded. The invariant is "every source skill gets installed",
# not "there are 25 of them" - a literal here breaks on every skill added and
# teaches whoever adds one to bump the number rather than read the failure.
NSKILLS=$(ls "$REPO"/skills/*.md | wc -l | tr -d ' ')

NP="$REPO/new-project.sh"
IN="$REPO/install.sh"
CP="$REPO/convert-to-parts.sh"
SP="$REPO/lib/seed-part.sh"

section "new-project.sh - the shape it creates"
w=$(workdir); (cd "$w" && "$NP" demo >/dev/null 2>&1)
p="$w/demo"
assert_exists   "creates the project"               "$p"
assert_absent   "creates no source directory"       "$p/src"
assert_exists   "writes blueprint/"                 "$p/blueprint"
assert_exists   "writes dev-notes/"                 "$p/dev-notes"
assert_exists   "writes AGENTS.md"                  "$p/AGENTS.md"
assert_eq       "installs every source skill"      "$NSKILLS" "$(ls "$p/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq       "an opencode command per skill"    "$NSKILLS" "$(ls "$p/.opencode/command" 2>/dev/null | wc -l | tr -d ' ')"
assert_ok       "both adapter trees are identical"  diff -rq "$p/.claude/skills" "$p/.agents/skills"

section "a part may be nested, and Product root points at the real root"
# Found by trying to adopt a real repository that was already an npm workspace
# (2026-09-08). `apps/web-app` was refused outright - "may not contain a slash" -
# so the most common JavaScript monorepo shape could not be represented at all.
# And `Product root:` was hardcoded to `..`, which is correct only one level
# down: a nested part resolved the board to `apps/` and found nothing, silently.
w=$(workdir); root="$w/prod"; mkdir -p "$root/apps/web-app"
"$REPO/lib/seed-product-root.sh" "$root" apps/web-app backend >/dev/null 2>&1
"$REPO/lib/seed-part.sh" "$root" apps/web-app --quiet
"$REPO/lib/seed-part.sh" "$root" backend --quiet
assert_exists "a nested part is created"            "$root/apps/web-app/AGENTS.md"
assert_eq "its Product root climbs two levels" "- Product root: ../.." \
  "$(grep -m1 '^- Product root:' "$root/apps/web-app/AGENTS.md")"
assert_eq "a top-level part still climbs one" "- Product root: .." \
  "$(grep -m1 '^- Product root:' "$root/backend/AGENTS.md")"
# The field is only useful if it resolves to the actual root.
assert_eq "and it resolves to the product root" "$(cd "$root" && pwd -P)" \
  "$(cd "$root/apps/web-app" && cd "$(grep -m1 '^- Product root:' AGENTS.md | sed 's/^- Product root: //')" && pwd -P)"
assert_eq "the status file uses the last segment, not the path" "web-app" \
  "$(ls "$root/blueprint/status" | grep -o 'web-app' | head -1)"

section "the root and the parts agree on how a part is named"
# They did not: seed-product-root.sh listed bare names while seed-part.sh listed
# paths, so adopting a five-part product produced a root describing eight - three
# of them directories that did not exist. Every file was individually valid and
# every linter rule passed.
listed=$(sed -n '/^## The parts/,/^## /p' "$root/AGENTS.md" | grep -cE '^- `[^`]+/`')
assert_eq "each part is listed exactly once" "2" "$listed"
assert_ok "and the nested one is listed by its path, so it can be found" \
  grep -q '^- `apps/web-app/`' "$root/AGENTS.md"

section "seed-part refuses a path that escapes the product root"
# `--parts '../x,api'` once created a sibling of the project and reported
# success. Allowing nesting must not reopen that: every SEGMENT is checked, so
# `apps/../../x` cannot pass a test that only looks for a leading '..'.
w2=$(workdir); root2="$w2/p2"; mkdir -p "$root2"
for bad in "../escape" "apps/../../escape" "/abs/path" "apps/-dash" "apps//empty"; do
  assert_fails "refuses '$bad'" "$REPO/lib/seed-part.sh" "$root2" "$bad"
done
assert_absent "and nothing was created outside the root" "$w2/escape"

section "two parts may not share a status file"
# `apps/web` and `services/web` are different parts whose last segment is the
# same, and the status file and board entry are both keyed on that segment - so
# the second silently adopts the first's live state. That is the one collision
# the board exists to prevent.
#
# The guard for it shipped unable to fire. The product root's AGENTS.md is
# written ~70 lines before the check, and the check required the entry it had
# just written to be ABSENT, so the condition was never true. Every file-level
# rule passed; the suite never executed the guard at all. Found by instrumenting
# all 30 guard exits in the pack and running the suite once to see which were
# reached - this was the only unreached one that did not work.
#
# It refuses before creating anything, so a refusal leaves no half-made part.
w4=$(workdir); root4="$w4/shop"; mkdir -p "$root4"
"$REPO/lib/seed-product-root.sh" "$root4" apps/web backend >/dev/null 2>&1
"$REPO/lib/seed-part.sh" "$root4" apps/web --quiet
assert_refuses "refuses a second part with the same last segment" \
  "a different part is already called" \
  "$REPO/lib/seed-part.sh" "$root4" services/web
assert_absent "and creates no directory for it"  "$root4/services/web"
assert_eq "the one part keeps its own status file" "1" \
  "$(ls "$root4/blueprint/status" | grep -c '^web\.md$')"
assert_fails "and the board never lists the refused part" \
  grep -q '^- `services/web/`' "$root4/AGENTS.md"
# A differently-named nested part is still fine - the guard keys on the segment,
# not on nesting, and refusing all nesting is the bug it was written after.
assert_ok "a nested part with its own name is still accepted" \
  "$REPO/lib/seed-part.sh" "$root4" services/api --quiet

section "seed-part reports what it actually did, not what the happy path does"
# It printed "Listed in the product root's AGENTS.md and on the board"
# unconditionally, while both writes are guarded by the file existing - so
# seeding into an unseeded root claimed a mechanism that was not there.
w3=$(workdir); root3="$w3/bare"; mkdir -p "$root3"
out3="$w3/out.txt"
"$REPO/lib/seed-part.sh" "$root3" api >"$out3" 2>&1
assert_eq "it does not claim the board listed it" "0" \
  "$(grep -c 'Listed on the board' "$out3" || true)"
assert_ok "it says the root is not seeded" grep -q 'product root is not seeded yet' "$out3"
assert_ok "and names the command that fixes it" grep -q 'seed-product-root.sh' "$out3"

section "the next-steps message names the loop that actually exists"
# Found by running the loop on a real project (2026-09-08): the closing message
# still said the source directory appears "once 'stack' has decided what this
# project is". `architect` runs before `stack` now, and `layout` is what decides
# the source directory.
#
# This is the very first thing a new user reads, before they have run anything,
# so a stale line here teaches the wrong loop and nothing later contradicts it.
# The linter cannot see it: script output is not a skill file.
# The message goes to a file rather than through a variable: it contains single
# quotes around every skill name, and nesting those through `bash -c` turned the
# quoted name into a filename argument - the grep looked for a file called
# "stack". Same class as the herestring bug in test-seams.sh: correct logic,
# broken by its own shell mechanics.
w=$(workdir); msg="$w/next-steps.txt"
(cd "$w" && "$NP" msgdemo >"$msg" 2>&1)
assert_ok "the message names architect"  grep -q "'architect'" "$msg"
assert_ok "and layout"                   grep -q "'layout'"    "$msg"
assert_ok "and still points at ideate"   grep -q "'ideate'"    "$msg"
assert_eq "and never says stack decides what scaffold creates" "0" \
  "$(grep -c "once 'stack' has decided" "$msg" || true)"

section "a created project has no placeholder work queued"
# The template shipped two live checkboxes - "First item", "Second item" - at
# column 0. Every skill reading build-plan.md treats an unchecked box as real
# work: `spec` with no argument specs the first, `progress` counts it as
# remaining, `prepare` files a requirement for whatever service it names. One
# real project ran for months with four items describing a different product
# entirely, and `progress` would have said "next up: Skill submission".
#
# An empty section stops the loop with "nothing is queued", which is obvious.
# Two fake items send it confidently in the wrong direction.
assert_eq "no live checkbox items in a fresh build plan" "0" \
  "$(grep -c '^- \[ \]' "$p/blueprint/build-plan.md" || true)"
assert_ok "the Format examples are still there, indented and inert" \
  bash -c "grep -q '^    - \[ \]' '$p/blueprint/build-plan.md'"
assert_ok "and it says what to run to get real ones" \
  grep -q 'ideate' "$p/blueprint/build-plan.md"

section "new-project.sh - git state"
# The branch was unborn until the script made a commit itself: branching before
# committing left nothing for ship's squash-merge to land on, and which happened
# depended only on the order the user worked in.
assert_eq "initial branch is main"      "main" "$(git -C "$p" branch --show-current)"
assert_eq "makes exactly one commit"    "1"    "$(git -C "$p" log --oneline 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "the first commit is clean"   "0"    "$(git -C "$p" ls-files | grep -cE '(^|/)\.env$|node_modules/')"

# `.gitignore` had `build/`, which matches at any depth - so every project this
# pack created committed 24 skills and the missing one was `build`. Invisible to
# every check here, because they all looked at the filesystem and never at git.
assert_eq "every skill is tracked by git" "$NSKILLS" \
  "$(git -C "$p" ls-files | grep -c '\.claude/skills/[^/]*/SKILL\.md$')"
assert_eq "the build skill specifically is tracked" "1" \
  "$(git -C "$p" ls-files | grep -c '\.claude/skills/build/SKILL\.md$')"

section "new-project.sh - path forms"
w=$(workdir)
assert_ok      "a bare name works"            env -C "$w" "$NP" bare
mkdir -p "$w/sub"
assert_ok      "a relative path works"        env -C "$w" "$NP" sub/nested
assert_ok      "an absolute path works"       "$NP" "$w/abs"
assert_ok      "--in DIR works"               "$NP" inned --in "$w"
assert_exists  "--in landed in DIR"           "$w/inned"
assert_eq      "an absolute name does not nest under \$PWD" "0" \
  "$(find "$w" -maxdepth 6 -path '*home*' -name AGENTS.md 2>/dev/null | wc -l | tr -d ' ')"

section "new-project.sh - refusals"
assert_fails   "refuses an existing directory"       env -C "$w" "$NP" bare
assert_refuses "refuses a missing parent" "" "$NP" "$w/no/such/parent/x"
assert_fails   "refuses an absolute path with --in"  "$NP" "$w/x" --in "$w"

section "part names - the guard that new-project.sh was missing"
# `--parts '../escaped,api'` created a sibling of the project and exited 0.
# convert-to-parts.sh had the guard; new-project.sh did not; both call
# lib/seed-part.sh, which is where the guard now lives.
w=$(workdir)
assert_fails  "refuses a traversing part name"  env -C "$w" "$NP" t --parts '../escaped,api'
assert_absent "and writes nothing outside the root" "$w/escaped"
assert_fails  "refuses '..' as a part"          env -C "$w" "$NP" t2 --parts '..,api'
assert_fails  "refuses a leading dash"          env -C "$w" "$NP" t3 --parts '-rf,api'
assert_fails  "refuses an absolute part path"   env -C "$w" "$NP" t4 --parts '/tmp/pwned,api'
assert_absent "and creates no absolute path"    "/tmp/pwned"
# The guard has to hold at the chokepoint too, or the callers are the only check
# and the rule drifts again the next time something calls seed-part.sh.
assert_refuses "seed-part.sh refuses it directly too" "not a usable part" \
  "$REPO/lib/seed-part.sh" "$w" '../sneaky'

# A refusal must leave nothing half-made, and every assertion above passed while
# it did: the target directory and its .gitignore were written seventy lines
# before --parts was ever looked at, so a refused run left `t/` on disk. The
# cost is not the stray directory. It is that the retry with the name corrected
# hits "Already exists: ... use install.sh instead", which sends the user to the
# wrong tool for what is a typo - and the guard's own comment claimed "nothing
# is created before a bad name is reported" the whole time.
assert_absent "a refused --parts leaves no half-made project" "$w/t"
assert_ok     "so the corrected retry is not blocked by it" \
  env -C "$w" "$NP" t --parts web,api
assert_exists "and the retry really built the product" "$w/t/blueprint/orchestration.md"

# A refusal that names no route is how a supported shape becomes unreachable.
# lib/seed-part.sh takes `apps/web` and docs/multi-part.md calls a nested part
# supported; both bulk callers refused it with "A part is a single directory
# name, not a path" and named nothing that does take one. The limit is real -
# each creates every part in one pass, and convert-to-parts.sh keys what it
# moves on a top-level name - so what has to hold is that the refusal says
# where to go, not that it disappears.
assert_refuses "new-project.sh sends a nested part to the route that takes one" \
  "lib/seed-part.sh" env -C "$w" "$NP" t5 --parts 'apps/web,api'
assert_absent  "and still creates nothing"  "$w/t5"
w2=$(workdir); (cd "$w2" && "$NP" conv >/dev/null 2>&1)
assert_refuses "convert-to-parts.sh does the same" \
  "lib/seed-part.sh" env -C "$w2/conv" "$CP" --parts 'apps/web,api' --existing 'apps/web'

section "new-project.sh --parts"
w=$(workdir); (cd "$w" && "$NP" prod --parts web,api >/dev/null 2>&1)
p="$w/prod"
assert_exists "creates the product root"        "$p/AGENTS.md"
assert_exists "creates each part"               "$p/web/AGENTS.md"
assert_exists "creates the second part"         "$p/api/AGENTS.md"
assert_exists "creates the board"               "$p/blueprint/orchestration.md"
assert_exists "creates a status file per part"  "$p/blueprint/status/web.md"
assert_exists "and for the other part"          "$p/blueprint/status/api.md"
assert_exists "creates contracts/"              "$p/contracts"
assert_eq     "the root has skills to run orchestrate from" "$NSKILLS" \
  "$(ls "$p/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq     "each part has the full set"      "$NSKILLS" \
  "$(ls "$p/web/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')"
assert_ok     "a part declares Part:"           grep -q '^- Part: web' "$p/web/AGENTS.md"
assert_ok     "a part declares Product root:"   grep -q '^- Product root:' "$p/web/AGENTS.md"
assert_absent "the product plan is not copied into a part" "$p/web/blueprint/project-plan.md"

section "the board names this product's real parts, not the template's examples"
# The board answers one question - where each part's state lives - and it shipped
# copied verbatim from the template, naming `web.md` and `api.md` whatever the
# parts were actually called. Every file was individually valid, so all 13 rules
# passed over a coordination file that was wrong about the thing it exists to
# record. Root AGENTS.md had a writer for its part list; the board did not.
#
# These names are deliberately NOT web/api. With those the bug is invisible,
# which is exactly how it survived - a test using them would have passed against
# the broken script.
w=$(workdir); (cd "$w" && "$NP" shop --parts frontend,backend >/dev/null 2>&1)
b="$w/shop/blueprint/orchestration.md"
assert_ok     "the board lists the first real part"   grep -q '^    blueprint/status/frontend\.md$' "$b"
assert_ok     "and the second"                        grep -q '^    blueprint/status/backend\.md$' "$b"
assert_fails  "and names no part that does not exist" grep -q '^    blueprint/status/web\.md$' "$b"
assert_fails  "the seeding placeholder is consumed"   grep -q '^    (none yet' "$b"

# Adding a part later has to reach the board too - that is the half that drifted.
"$SP" "$w/shop" worker >/dev/null 2>&1
assert_ok  "a part added later is listed too" grep -q '^    blueprint/status/worker\.md$' "$b"
assert_eq  "and listed exactly once" "1" \
  "$(grep -c '^    blueprint/status/worker\.md$' "$b")"

# The invariant the three above are instances of: the board and the directory
# agree in both directions.
unlisted=""
for f in "$w/shop"/blueprint/status/*.md; do
  n=$(basename "$f")
  grep -q "^    blueprint/status/$n\$" "$b" || unlisted="$unlisted $n"
done
assert_eq "every status file the product has is named on the board" "" "$unlisted"

phantom=""
while read -r n; do
  [ -e "$w/shop/blueprint/status/$n" ] || phantom="$phantom $n"
done < <(sed -n 's|^    blueprint/status/\(.*\.md\)$|\1|p' "$b")
assert_eq "and the board names no status file that is missing" "" "$phantom"

# The converter builds a product too, and shares lib/ so it cannot drift - but
# that is the claim, and this is the check.
w2=$(workdir); (cd "$w2" && "$NP" conv2 >/dev/null 2>&1)
(cd "$w2/conv2" && "$CP" --parts ui,svc --existing ui >/dev/null 2>&1)
b2="$w2/conv2/blueprint/orchestration.md"
assert_ok    "the converted product's board names its parts" grep -q '^    blueprint/status/ui\.md$' "$b2"
assert_fails "and not the template's"                        grep -q '^    blueprint/status/web\.md$' "$b2"

section "concurrent sessions cannot corrupt each other's status files"
# The multi-part design rests on one claim: separate files remove the write race
# by construction. That was reasoning, not a measurement, until this ran. Three
# writers, 300 rewrites each, genuinely concurrent.
w=$(workdir); (cd "$w" && "$NP" race --parts web,api >/dev/null 2>&1)
"$SP" "$w/race" worker >/dev/null 2>&1
st="$w/race/blueprint/status"
_writer() {
  for i in $(seq 1 200); do
    printf '# %s\n\n**State:** building\n**Item:** %s\n**Blocked on:** -\n**Review packet:** -\n**Updated:** 2026-09-07\n' "$1" "$i" > "$st/$1.md"
  done
}
_writer web & _writer api & _writer worker & wait

intact=0
for n in web api worker; do
  [ "$(head -1 "$st/$n.md")" = "# $n" ] \
    && grep -q '^\*\*Item:\*\* 200$' "$st/$n.md" \
    && [ "$(wc -l < "$st/$n.md")" -eq 7 ] && intact=$((intact + 1))
done
assert_eq "all three survive 600 concurrent writes intact" "3" "$intact"

# The control: the design the board explicitly rejected, under the same load.
# Without this the claim above is only that the chosen design works, not that
# the rejected one fails - and that is the half that justifies the choice.
sh_file="$w/race/shared-table.md"
printf '| part | item |\n|---|---|\n| web | 0 |\n| api | 0 |\n| worker | 0 |\n' > "$sh_file"
_shared() {
  for i in $(seq 1 200); do
    python3 -c "
import sys,pathlib,re
p=pathlib.Path(sys.argv[1]); s=p.read_text()
p.write_text(re.sub(rf'^\| {sys.argv[2]} \| \d+ \|$', f'| {sys.argv[2]} | {sys.argv[3]} |', s, flags=re.M))
" "$sh_file" "$1" "$i"
  done
}
# Losing a row is a race, so a single round is near-certain but not certain, and
# a control that fails spuriously is worse than no control. Three rounds; the
# claim is that the shared design loses rows, not that it loses them every time.
lost=no
for _round in 1 2 3; do
  printf '| part | item |\n|---|---|\n| web | 0 |\n| api | 0 |\n| worker | 0 |\n' > "$sh_file"
  _shared web & _shared api & _shared worker & wait
  [ "$(grep -c '^| \(web\|api\|worker\) |' "$sh_file")" -eq 3 ] || { lost=yes; break; }
done
assert_eq "a shared table under the same load loses rows" "yes" "$lost"

section "adding a part reports it, without making the bulk callers repeat it"
# README documents lib/seed-part.sh as the way to add a part to an existing
# product. It created a directory, a full skill set, a status file and two list
# entries, and printed nothing at all - exit 0, no output, go and look. The two
# internal callers print their own summary, so they pass --quiet; without that
# split, fixing the silence would have made `new-project.sh --parts` repeat
# itself once per part.
w=$(workdir); (cd "$w" && "$NP" prod --parts web,api >/dev/null 2>&1)
out=$("$SP" "$w/prod" mobile 2>&1)
assert_ok "the standalone command says what it made" \
  grep -q "Added part 'mobile'" <<< "$out"
assert_ok "and names where the part's live state actually lives" \
  grep -q 'blueprint/status/mobile.md' <<< "$out"
assert_ok "and points at the product root, not the part" \
  grep -q 'never inside the part' <<< "$out"

w2=$(workdir)
np_out=$(cd "$w2" && "$NP" prod2 --parts web,api 2>&1)
assert_eq "new-project.sh does not repeat it per part" "0" \
  "$(grep -c 'Added part' <<< "$np_out" | tr -d ' ')"

w3=$(workdir); (cd "$w3" && "$NP" conv3 >/dev/null 2>&1)
cv_out=$(cd "$w3/conv3" && "$CP" --parts ui,svc --existing ui 2>&1)
assert_eq "and neither does the converter" "0" \
  "$(grep -c 'Added part' <<< "$cv_out" | tr -d ' ')"

section "install.sh knows a product root from a part"
# A product root takes the skills and nothing else. README documented
# --skills-only for it, but a flag you must remember is not a guard: run without
# it and the root gained a fundamentals.md it has no use for, and six AGENTS.md
# sections were reported as legacy drift - because a product root's AGENTS.md
# comes from template/product/AGENTS.md and was being compared against the part
# template. It told the user to run `setup` over a file that was already right.
w=$(workdir); (cd "$w" && "$NP" prod --parts web,api >/dev/null 2>&1)
before=$(find "$w/prod" -not -path '*/.git/*' -not -path '*/skills/*' -not -path '*/.opencode/*' -type f | sort)
root_out=$("$IN" --target "$w/prod" 2>&1)
after=$(find "$w/prod" -not -path '*/.git/*' -not -path '*/skills/*' -not -path '*/.opencode/*' -type f | sort)

assert_eq "installing over a product root adds no build-loop files" "$before" "$after"
assert_ok "and says it detected one, rather than changing mode silently" \
  grep -q 'product root detected' <<< "$root_out"
assert_fails "and reports no AGENTS.md section as missing" \
  grep -q 'AGENTS.md has no:' <<< "$root_out"
assert_absent "no fundamentals.md at a root that builds no code" \
  "$w/prod/blueprint/context/fundamentals.md"

# The detection must not catch a part, which declares Part: and needs the loop.
part_out=$("$IN" --target "$w/prod/web" 2>&1)
assert_fails "a part is not mistaken for a root" \
  grep -q 'product root detected' <<< "$part_out"
assert_exists "and keeps its build-loop files" "$w/prod/web/blueprint/build-plan.md"

section "a board naming parts that do not exist is reported, never rewritten"
# Products seeded before the board's part list had a writer name web.md and
# api.md whatever their parts are called. The board holds the frozen contract
# line, so it is the user's file - this reports and leaves it alone.
w2=$(workdir); (cd "$w2" && "$NP" old --parts frontend,backend >/dev/null 2>&1)
b="$w2/old/blueprint/orchestration.md"
python3 - "$b" <<'PYEOF'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"^    blueprint/status/\w+\.md$", "", s, flags=re.M)
s = s.replace("**One file per part**, under `blueprint/status/`:",
              "**One file per part**, under `blueprint/status/`:\n\n    blueprint/status/web.md\n    blueprint/status/api.md")
p.write_text(s)
PYEOF
stale=$("$IN" --target "$w2/old" 2>&1)
assert_ok "it names the file that does not exist" grep -q 'web.md' <<< "$stale"
assert_ok "and the real part the board omits"    grep -q 'frontend.md' <<< "$stale"
assert_ok "and says the board is the user's to fix" \
  grep -q 'nothing here rewrites it' <<< "$stale"
assert_ok "the board itself is untouched" grep -q 'blueprint/status/web.md' "$b"

# The report lived inside the non-skills-only branch, so --skills-only silently
# suppressed every legacy finding - and --skills-only is the documented mode for
# a product root, the only place this particular finding can occur. The report
# existed and could never reach its own case. Explicit flag, not just detection.
explicit=$("$IN" --target "$w2/old" --skills-only 2>&1)
assert_ok "legacy findings survive an explicit --skills-only" \
  grep -q 'lists the wrong parts' <<< "$explicit"

section "a context file that lands on upgrade does not land unloaded"
# CLAUDE.md is the user's and is never rewritten, so a project created before a
# context file existed keeps an import list that predates it: install writes the
# file into blueprint/context/ and no session ever loads it. Found on a real
# project - one took fundamentals.md and needs-you.md this way.
w=$(workdir); (cd "$w" && "$NP" old >/dev/null 2>&1)
# age the project: drop the two newest imports, as an older CLAUDE.md would have
python3 - "$w/old/CLAUDE.md" <<'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
p.write_text("".join(l for l in p.read_text().splitlines(keepends=True)
                     if "fundamentals.md" not in l and "needs-you.md" not in l))
PYEOF
aged=$("$IN" --target "$w/old" 2>&1)
assert_ok "install names the context files nothing loads" \
  grep -q 'CLAUDE.md does not load' <<< "$aged"
assert_ok "and names them individually" grep -q 'needs-you.md' <<< "$aged"
assert_ok "and gives the exact import line to add" \
  grep -q '@blueprint/context/needs-you.md' <<< "$aged"
assert_ok "while leaving CLAUDE.md alone - it is the user's file" \
  test "$(grep -c 'needs-you' "$w/old/CLAUDE.md")" -eq 0

# A current project must not trip it, or the report is noise nobody reads.
w2=$(workdir); (cd "$w2" && "$NP" fresh >/dev/null 2>&1)
fresh_out=$("$IN" --target "$w2/fresh" 2>&1)
assert_fails "a project created by this pack reports nothing" \
  grep -q 'does not load' <<< "$fresh_out"

section "opencode wrappers carry the modes the skill declares"
# Rule 15 makes sure a mode is named in the skill's own description, which is
# what Claude Code matches on. The opencode wrapper keeps only the FIRST
# SENTENCE of that description, so no mode ever survived into it - and in
# opencode the wrapper is what the command menu shows and what the model matches
# a request against. `/ideate --rescope` worked, because $ARGUMENTS reaches the
# skill body; nobody could discover it existed. Rule 15 held in one tool of two.
w=$(workdir); (cd "$w" && "$NP" wr >/dev/null 2>&1)
c="$w/wr/.opencode/command"
assert_ok "a declared mode reaches the wrapper" \
  grep -q 'Modes this skill declares: --rescope' "$c/ideate.md"
assert_ok "and so do multi-argument scopes" \
  grep -q 'Modes this skill declares: current changed full' "$c/review.md"
assert_fails "a skill with no declared modes gets no modes line" \
  grep -q 'Modes this skill' "$c/build.md"
assert_ok "the wrapper still passes arguments through to the skill" \
  grep -q '\$ARGUMENTS' "$c/ideate.md"

# Every mode rule 15 enforces in the description must reach the wrapper too, or
# the guarantee is only true in Claude Code.
missing=""
for f in "$REPO"/skills/*.md; do
  n=$(basename "$f" .md)
  args=$(sed -n '/^## Input/,/^## [^I]/p' "$f" | grep -oE '^\| `[^`]+`' | sed 's/^| //; s/`//g' | sort -u || true)
  for a in $args; do
    grep -qF -- "$a" "$c/$n.md" || missing="$missing $n:$a"
  done
done
assert_eq "no declared mode is missing from its wrapper" "" "$missing"

section "a single-part project is unaffected by the multi-part machinery"
w=$(workdir); (cd "$w" && "$NP" solo >/dev/null 2>&1)
assert_absent "no board"                "$w/solo/blueprint/orchestration.md"
assert_absent "no status directory"     "$w/solo/blueprint/status"
assert_fails  "no Part: field"          grep -q '^- Part: ' "$w/solo/AGENTS.md"

section "install.sh - into a project that already exists"
w=$(workdir); mkdir -p "$w/existing/src"
printf '{"name":"mine"}\n' > "$w/existing/package.json"
printf 'console.log(1)\n'  > "$w/existing/src/index.js"
assert_ok  "installs into an existing tree"  "$IN" --target "$w/existing"
assert_eq  "leaves the project's files alone" '{"name":"mine"}' "$(cat "$w/existing/package.json")"
assert_exists "installs the skills"          "$w/existing/.claude/skills/build/SKILL.md"

# A plain re-install upgrades skills. It used to keep any that differed, on the
# assumption that a difference meant a local edit - it usually means the pack
# moved on, so re-installing upgraded nothing and you had to know to pass
# --force. A stale skill is invisible and behaves like a current one.
printf 'stale-from-an-old-version\n' > "$w/existing/.claude/skills/spec/SKILL.md"
assert_ok "a plain re-install runs" "$IN" --target "$w/existing"
assert_fails "and upgrades a stale skill without --force" \
  grep -qx stale-from-an-old-version "$w/existing/.claude/skills/spec/SKILL.md"
assert_ok "the upgraded skill matches the source" \
  cmp -s "$REPO/skills/spec.md" "$w/existing/.claude/skills/spec/SKILL.md"

printf 'edited\n' >> "$w/existing/.claude/skills/build/SKILL.md"
printf 'my plan\n' > "$w/existing/blueprint/project-plan.md"
assert_ok    "--force re-installs"                "$IN" --target "$w/existing" --force
assert_fails "--force replaced the edited skill"  grep -q '^edited$' "$w/existing/.claude/skills/build/SKILL.md"
assert_eq    "--force left the plan alone" "my plan" "$(cat "$w/existing/blueprint/project-plan.md")"

section "pack-owned files refresh on install; project-owned never do"
# A template file used to freeze at install time forever. A project set up
# months earlier still had a findings.md naming skills that no longer exist and
# a CLAUDE.md importing a file nothing writes - and `setup` was correcting all
# of it by hand, 1741 deleted lines the installer should have done.
#
# The boundary is ownership, not staleness: a file the project never edits is
# refreshed, a file holding project content is never touched even when the
# template moves on.
w=$(workdir); (cd "$w" && "$NP" own >/dev/null 2>&1)
p="$w/own"
printf 'STALE\n' > "$p/blueprint/context/fundamentals.md"
printf 'STALE\n' > "$p/blueprint/history/features/README.md"
printf 'MINE\n'  > "$p/blueprint/context/coding-standards.md"
printf 'MY PLAN\n' > "$p/blueprint/project-plan.md"
printf 'MY ITEMS\n' > "$p/blueprint/build-plan.md"
assert_ok "re-install runs" "$IN" --target "$p"

assert_fails "the pack's fundamentals are refreshed" grep -qx STALE "$p/blueprint/context/fundamentals.md"
assert_fails "so are the history READMEs"            grep -qx STALE "$p/blueprint/history/features/README.md"
assert_eq "this project's standards are NOT touched" "MINE"     "$(cat "$p/blueprint/context/coding-standards.md")"
assert_eq "nor is the plan"                          "MY PLAN"  "$(cat "$p/blueprint/project-plan.md")"
assert_eq "nor the build plan"                       "MY ITEMS" "$(cat "$p/blueprint/build-plan.md")"

# The split exists so the fundamentals can be refreshed at all. One file with a
# pack-owned half and a project-owned half is a file with two writers, which is
# what left every existing project without the curated list.
assert_ok "fundamentals ships separately" test -f "$REPO/template/blueprint/context/fundamentals.md"
assert_fails "and is not still inside coding-standards" \
  grep -q '^# Part 1' "$REPO/template/blueprint/context/coding-standards.md"

section "opencode wrappers are generated, so they refresh like skills do"
# The wrapper is generated from the skill's frontmatter, which makes it a
# pack-owned artifact with one source - the same category as the skill itself.
# It used to be written only when absent, so a description could change, the
# installed skill would take the new text, and the wrapper would keep the old.
# In opencode the wrapper's description is what the command menu shows and what
# the model matches a request against, so the stale copy is the visible one.
w=$(workdir); (cd "$w" && "$NP" wrap >/dev/null 2>&1)
p="$w/wrap"
printf 'STALE WRAPPER\n' > "$p/.opencode/command/verify.md"
rm -f "$p/.opencode/command/spec.md"
out=$("$IN" --target "$p" 2>&1)

assert_fails "a stale wrapper is rewritten without --force" \
  grep -qx 'STALE WRAPPER' "$p/.opencode/command/verify.md"
assert_exists "a deleted wrapper comes back" "$p/.opencode/command/spec.md"
assert_ok "the rewrite is reported, not silent" \
  grep -q 'rewritten from a different version:.*verify' <<< "$out"
# The description is the half that matters: it is what opencode matches on.
assert_ok "the wrapper carries the skill's current description" \
  grep -q "$(sed -n 's/^description:[[:space:]]*"\{0,1\}//p' "$REPO/skills/verify.md" \
            | head -1 | sed 's/\. .*//' | cut -c1-40)" "$p/.opencode/command/verify.md"
# An unchanged wrapper must not be reported as rewritten, or the line becomes
# noise on every install and stops being read.
out=$("$IN" --target "$p" 2>&1)
assert_fails "an unchanged wrapper is not reported" \
  grep -q 'rewritten from a different version' <<< "$out"

section "legacy shapes are reported, never rewritten"
# A project from before a structural change carries the old shape. The installer
# must not fix it: these are project-owned files, and a merge needs judgement a
# script has not got - the first real `setup` run corrected four wrong rules
# while restructuring, and stripping "the duplicated part" would have deleted
# those corrections too. So it names the problem and touches nothing.
w=$(workdir); (cd "$w" && "$NP" legacy >/dev/null 2>&1)
p="$w/legacy"
printf '# Coding Standards\n\n## Part 1 - Fundamentals\n\nMY OLD RULES\n' \
  > "$p/blueprint/context/coding-standards.md"
mkdir -p "$p/blueprint/.state"; printf '{}\n' > "$p/blueprint/.state/manifest.json"
out=$("$IN" --target "$p" 2>&1)

assert_eq "the stale Part 1 is left exactly as it was" \
  "$(printf '# Coding Standards\n\n## Part 1 - Fundamentals\n\nMY OLD RULES')" \
  "$(cat "$p/blueprint/context/coding-standards.md")"
assert_exists "the old state directory is not deleted either" "$p/blueprint/.state/manifest.json"
assert_ok "it reports the stale Part 1"    bash -c 'printf "%s" "$1" | grep -q "still has its own"' _ "$out"
assert_ok "it names setup as the fixer"    bash -c 'printf "%s" "$1" | grep -q "Run .setup. to reconcile"' _ "$out"
assert_ok "it reports the old state dir"   bash -c 'printf "%s" "$1" | grep -q "blueprint/.state/ is from an older pack"' _ "$out"
assert_ok "setup knows how to merge it"    grep -q 'has its own "Part 1"' "$REPO/skills/setup.md"

# A project with neither must not be told it has them.
w2=$(workdir); (cd "$w2" && "$NP" clean >/dev/null 2>&1)
out2=$("$IN" --target "$w2/clean" 2>&1)
assert_fails "a clean project gets no legacy report" \
  bash -c 'printf "%s" "$1" | grep -q "From an older version"' _ "$out2"

section "the closing advice tells a first install from an upgrade"
# "Run setup" is right for a first install and wrong for an upgrade: a project
# part-way through the loop has already been tuned. The first attempt inferred
# it from what had been written and got it exactly backwards - on a first
# install every pack-owned file is new, which looks identical to nothing needing
# an update. Decided before anything is written instead.
w=$(workdir); mkdir -p "$w/fresh"
first=$("$IN" --target "$w/fresh" 2>&1)
again=$("$IN" --target "$w/fresh" 2>&1)
assert_ok "a first install points at setup" \
  bash -c 'printf "%s" "$1" | grep -q "run .setup. so the workflow"' _ "$first"
assert_fails "and does not claim the workflow was already there" \
  bash -c 'printf "%s" "$1" | grep -q "already had the workflow"' _ "$first"
assert_ok "a re-install points at progress instead" \
  bash -c 'printf "%s" "$1" | grep -q "run .progress. to see where it stands"' _ "$again"
assert_fails "and does not tell you to re-run setup" \
  bash -c 'printf "%s" "$1" | grep -q "run .setup. so the workflow"' _ "$again"

section "AGENTS.md sections added after a project was set up are reported"
# AGENTS.md is project-owned, so it is never overwritten - which means a section
# added to the template later never reaches an existing project. One had no
# Environments table while nine skills read it, including `migrate`, whose rule
# is that an environment *not* in the table holds real data. Reported, never
# inserted: the file is the user's and a section may have been deleted on purpose.
w=$(workdir); (cd "$w" && "$NP" drift >/dev/null 2>&1)
p="$w/drift"
# Just the heading - that is what the comparison looks at, and it avoids
# assuming Environments has another section after it (it does not).
sed -i '/^## Environments$/d' "$p/AGENTS.md"
out=$("$IN" --target "$p" 2>&1)
assert_ok "a missing section is named"   bash -c 'printf "%s" "$1" | grep -q "AGENTS.md has no: Environments"' _ "$out"
assert_ok "and setup is named as the fixer" bash -c 'printf "%s" "$1" | grep -q "setup. fills them in"' _ "$out"
assert_fails "the file itself is not edited" grep -q '^## Environments' "$p/AGENTS.md"

w2=$(workdir); (cd "$w2" && "$NP" clean2 >/dev/null 2>&1)
out2=$("$IN" --target "$w2/clean2" 2>&1)
assert_fails "a current project is not nagged" \
  bash -c 'printf "%s" "$1" | grep -q "AGENTS.md has no"' _ "$out2"

section "upgrading prunes this pack's retired skills, and only those"
# Installing never removed anything, so a project set up long ago kept every
# skill it was ever given. A real one had 42 installed, 16 from a predecessor
# pack - all loaded by the agent, all contradicting the current workflow.
# check.sh rule 5 catches a stale reference inside this repo; nothing caught
# stale files inside a project, which is the copy anyone runs against.
w=$(workdir); (cd "$w" && "$NP" old >/dev/null 2>&1)
p="$w/old"
retired_name=$(grep -v '^#' "$REPO/lib/retired-names" | grep -v '^[[:space:]]*$' | head -1)
for a in .claude/skills .agents/skills; do
  mkdir -p "$p/$a/$retired_name" "$p/$a/my-own-thing"
  printf 'stale\n' > "$p/$a/$retired_name/SKILL.md"
  printf 'mine\n'  > "$p/$a/my-own-thing/SKILL.md"
done
assert_ok "re-install runs"  "$IN" --target "$p" --force
assert_absent "a retired skill is removed"        "$p/.claude/skills/$retired_name"
assert_absent "removed from the other adapter too" "$p/.agents/skills/$retired_name"
assert_exists "an unrecognised skill is KEPT"      "$p/.claude/skills/my-own-thing"
assert_eq "and its content is untouched" "mine" "$(cat "$p/.claude/skills/my-own-thing/SKILL.md")"
assert_eq "every current skill is still installed" "$NSKILLS" \
  "$(for d in "$p"/.claude/skills/*/; do n=$(basename "$d"); [ -f "$REPO/skills/$n.md" ] && echo x; done | wc -l | tr -d ' ')"
assert_refuses "the report names what it kept" "not from this pack" \
  bash -c '"$0" --target "$1" --force | grep "not from this pack" && exit 1' "$IN" "$p"

section "check.sh and install.sh read the same retired list"
# Two copies of that list is how the two stop agreeing - the same reason the
# seed scripts are shared between new-project.sh and convert-to-parts.sh.
assert_ok "check.sh reads lib/retired-names"   grep -q 'lib/retired-names' "$REPO/check.sh"
assert_ok "install.sh reads lib/retired-names" grep -q 'lib/retired-names' "$REPO/install.sh"
assert_fails "neither hardcodes the old inline list" \
  grep -q 'retired="release feature' "$REPO/check.sh"

section "re-installing over a multi-part product - the upgrade path"
# Picking up new skills means re-running install.sh over an existing product.
# It used to write files that are silently wrong rather than harmless: a stub
# project-plan.md inside a part is what an unqualified `blueprint/` resolves to,
# so a part would read an empty plan instead of the real one a level up -
# undoing the deletion lib/seed-part.sh performs for exactly that reason.
w=$(workdir); (cd "$w" && "$NP" prod --parts web,api >/dev/null 2>&1)
p="$w/prod"
printf 'REAL PRODUCT PLAN\n' > "$p/blueprint/project-plan.md"
printf 'REAL WEB ITEMS\n'    > "$p/web/blueprint/build-plan.md"
for d in "$p" "$p/web" "$p/api"; do "$IN" --target "$d" --force >/dev/null 2>&1; done

assert_absent "no stub plan appears inside a part"        "$p/web/blueprint/project-plan.md"
assert_absent "nor inside the other part"                 "$p/api/blueprint/project-plan.md"
assert_absent "no build plan appears at the product root" "$p/blueprint/build-plan.md"
assert_absent "no current-work at the product root"       "$p/blueprint/context/current-work.md"
assert_eq "the real product plan survives" "REAL PRODUCT PLAN" "$(cat "$p/blueprint/project-plan.md")"
assert_eq "a part's real build plan survives" "REAL WEB ITEMS" "$(cat "$p/web/blueprint/build-plan.md")"
assert_eq "every part still has the full skill set" "$NSKILLS" \
  "$(ls "$p/web/.claude/skills" | wc -l | tr -d ' ')"
assert_exists "the board is untouched" "$p/blueprint/orchestration.md"

section "convert-to-parts.sh"
w=$(workdir); (cd "$w" && "$NP" conv >/dev/null 2>&1)
assert_ok     "converts a single-part project" env -C "$w/conv" "$CP" --parts web,api --existing web
assert_exists "the board appears"              "$w/conv/blueprint/orchestration.md"
assert_exists "both parts appear"              "$w/conv/api/AGENTS.md"
assert_exists "the status files appear"        "$w/conv/blueprint/status/web.md"
assert_exists "the product plan stays at the root" "$w/conv/blueprint/project-plan.md"
assert_refuses "refuses a part name with a slash" "Not a usable part name" \
  env -C "$w/conv" "$CP" --parts 'a/b,api' --existing api

section "convert-to-parts.sh will not move a project it cannot undo"
# This moves every file in the project. Without git there is no way back; with a
# dirty tree the move is tangled up with work in progress instead of being one
# reviewable diff. The guard was written with those messages and then never
# tested - the most destructive path in the pack, held by nothing. Running it by
# hand is what found the count bug the stderr assertion below now covers.
w=$(workdir); (cd "$w" && "$NP" nogit --no-git >/dev/null 2>&1)
assert_refuses "refuses a project with no git" "is not a git repository" \
  env -C "$w/nogit" "$CP" --parts a,b --existing a
assert_exists "and nothing was moved"      "$w/nogit/blueprint/build-plan.md"
assert_absent "no part directory appeared" "$w/nogit/a"

w=$(workdir); (cd "$w" && "$NP" dirty >/dev/null 2>&1)
printf 'work in progress\n' > "$w/dirty/wip.txt"
assert_refuses "refuses an uncommitted tree" "has uncommitted changes" \
  env -C "$w/dirty" "$CP" --parts a,b --existing a
assert_exists "the uncommitted file is untouched" "$w/dirty/wip.txt"
assert_absent "and no part directory appeared"    "$w/dirty/a"

# The refusal has to be overridable, or a project without git can never convert.
assert_ok     "--allow-dirty accepts it deliberately" \
  env -C "$w/dirty" "$CP" --parts a,b --existing a --allow-dirty
assert_exists "and the uncommitted file moves with the project" "$w/dirty/a/wip.txt"

section "convert-to-parts.sh refuses what it must not convert"
# Four guards, none of them ever executed by a test until now - the same probe
# that found the seed-part one. These all work; nothing held them in place.
w=$(workdir); (cd "$w" && "$NP" cv1 >/dev/null 2>&1)
assert_refuses "refuses --existing that is not one of --parts" \
  "is not in --parts" \
  env -C "$w/cv1" "$CP" --parts a,b --existing zzz
assert_absent  "and moves nothing" "$w/cv1/a"

mkdir -p "$w/cv1/a"
assert_refuses "refuses a part directory that already exists" \
  "already exists - pick part names" \
  env -C "$w/cv1" "$CP" --parts a,b --existing a
rmdir "$w/cv1/a"

mkdir -p "$w/plain" && (cd "$w/plain" && git init -q .)
assert_refuses "refuses a project without the workflow" \
  "does not look like a project built with this workflow" \
  env -C "$w/plain" "$CP" --parts a,b --existing a
assert_absent  "and seeds no board into it" "$w/plain/blueprint"

(cd "$w" && "$NP" cv2 --parts x,y >/dev/null 2>&1)
assert_refuses "refuses a product that is already multi-part" \
  "already a multi-part project" \
  env -C "$w/cv2" "$CP" --parts a,b --existing a
assert_exists  "and leaves its existing parts alone" "$w/cv2/x/AGENTS.md"

section "created and converted products are the same shape"
# The two routes share lib/ precisely so they cannot drift. This is the check
# that says so - and note it compares *file trees*, which is why it could never
# have caught the part-name guard being on only one of the two routes.
w=$(workdir)
(cd "$w" && "$NP" made --parts web,api >/dev/null 2>&1)
(cd "$w" && "$NP" turned >/dev/null 2>&1 && cd turned && "$CP" --parts web,api --existing web >/dev/null 2>&1)
( cd "$w/made"   && find . -path ./.git -prune -o -type f -print | sort > "$TEST_TMP/made.txt" )
( cd "$w/turned" && find . -path ./.git -prune -o -type f -print | sort > "$TEST_TMP/turned.txt" )
assert_ok "identical file trees" diff -q "$TEST_TMP/made.txt" "$TEST_TMP/turned.txt"


section "the created project reports git honestly"
# It printed two contradictory lines at once - "with that first commit already
# made" and "initialised, nothing committed yet". The second was a leftover from
# before the script started committing. Not cosmetic: "nothing committed yet"
# tells the user to branch before committing, and an unborn base branch is
# exactly what broke a real project's first `ship`.
w=$(workdir); out=$(cd "$w" && "$NP" gitrep 2>&1)
assert_ok    "says the first commit was made" grep -q "first commit already made" <<< "$out"
assert_fails "and does not also say nothing was committed" \
  grep -q "nothing committed yet" <<< "$out"
assert_eq    "which is true: one commit exists" "1" \
  "$(git -C "$w/gitrep" rev-list --count HEAD)"
assert_eq    "on main" "main" "$(git -C "$w/gitrep" rev-parse --abbrev-ref HEAD)"

# --no-git must not claim a repository or a commit that does not exist.
w2=$(workdir); out2=$(cd "$w2" && "$NP" nogit --no-git 2>&1)
assert_fails "--no-git claims no commit"      grep -q "first commit already made" <<< "$out2"
assert_fails "--no-git claims no git init"    grep -q "before git init" <<< "$out2"
assert_absent "--no-git creates no repository" "$w2/nogit/.git"

section ".gitignore covers the ecosystems stack can choose"
# It listed node_modules, .venv, __pycache__, vendor, dist - JS, Python, Ruby.
# Nothing for .NET, Rust or the JVM. After one `dotnet build` in a real project,
# `git add -A` staged 156 files from bin/ and obj/. `obj/` is .NET's restore
# output, so it is a dependency directory as much as a build one, and the claim
# "the first commit is clean, no dependency directory staged" was true only for
# the ecosystems someone had happened to use.
w=$(workdir); (cd "$w" && "$NP" ig >/dev/null 2>&1)
p="$w/ig"
mkdir -p "$p/api/bin" "$p/api/obj" "$p/target" "$p/src/bin"
: > "$p/api/bin/App.dll"; : > "$p/api/obj/project.assets.json"
: > "$p/target/debug.bin"; : > "$p/src/bin/tool"
(cd "$p" && git add -A >/dev/null 2>&1)
assert_eq "no .NET/Rust build output is staged" "0" \
  "$(cd "$p" && git diff --cached --name-only | grep -cE '(^|/)(bin|obj|target)/')"
# ...and the patterns must not eat the workflow, the way `build/` once ate the
# `build` skill. That bug shipped in every project for weeks.
assert_eq "every skill is still tracked" "$NSKILLS" \
  "$(cd "$p" && git ls-files | grep -c 'claude/skills/.*\.md')"

section "converting reports what it moved into one part"
# Everything part-local moves into --existing and the other parts are seeded
# empty. For a build plan that is wrong: `ideate` writes product features, it
# runs once at the product root, and after the split nothing writes an initial
# item set again - so the other part's plan stays empty and `spec` run there
# reports "nothing is queued" while its whole surface is unbuilt.
#
# Reported, never split: telling a product feature from a front-end-only one is
# judgement. Same rule as install.sh - name it, and name who fixes it.
w=$(workdir); (cd "$w" && "$NP" cvr >/dev/null 2>&1)
p="$w/cvr"
python3 - "$p" <<'PY'
import sys
b=f"{sys.argv[1]}/blueprint/build-plan.md"; s=open(b).read()
open(b,"w").write(s.replace('_No items yet. Run `ideate` to write them from the plan._',
  "- [ ] 1. **A thing** - do it\n- [ ] 2. **Another** - do that"))
open(f"{sys.argv[1]}/blueprint/context/needs-you.md","a").write("\n### An account\n\n- **Status** - open\n")
open(f"{sys.argv[1]}/dev-notes/decisions.md","a").write("\n## D1 - A choice (2026-01-01)\n\nChosen: x.\n")
PY
(cd "$p" && git add -A >/dev/null 2>&1 && git commit -q -m plans)
out=$(cd "$p" && "$CP" --parts web,api --existing web 2>&1)
assert_ok "names the unsplit build plan"  grep -q "build-plan.md has 2 unchecked item" <<< "$out"
assert_ok "names the open needs-you line" grep -q "needs-you.md has 1 open line"       <<< "$out"
assert_ok "names the pre-split decision"  grep -q "decisions.md has 1 entry"           <<< "$out"
assert_ok "and says nothing here splits them" grep -q "Nothing here splits these"      <<< "$out"
assert_ok "the other part's plan really is empty" \
  bash -c "! grep -q '^- \[ \]' '$p/api/blueprint/build-plan.md'"

# A project with nothing to split must stay quiet, or the line is noise on every
# conversion and stops being read.
w2=$(workdir); (cd "$w2" && "$NP" cvq >/dev/null 2>&1)
(cd "$w2/cvq" && git add -A >/dev/null 2>&1; git commit -q -m x 2>/dev/null)
out2=$(cd "$w2/cvq" && "$CP" --parts web,api --existing web 2>&1)
assert_ok    "an empty project still converts" grep -q "Converted" <<< "$out2"
assert_fails "and gets no split report"        grep -q "written before there were parts" <<< "$out2"

# stderr on its own. A script that has just moved every file in the project must
# say nothing there on its happy path, and `2>&1` above cannot see the
# difference - it hid this for as long as the bug lived: `grep -c` exits 1 when
# it matches nothing, so `|| echo 0` made the count "0\n0" and each `[ -gt ]`
# printed "integer expected". Three of them, on exactly this quiet path, where
# every count is zero.
w3=$(workdir); (cd "$w3" && "$NP" cvs >/dev/null 2>&1)
err=$(cd "$w3/cvs" && "$CP" --parts web,api --existing web 2>&1 >/dev/null)
assert_eq "a clean conversion prints nothing to stderr" "" "$err"


section "a local database is never committed"
# Found by looking at a real project's git status after building it: it had
# committed its dev SQLite file, and `git show HEAD:...db | strings` read the
# rows straight back. A dev database fills with real rows while you
# test, and .gitignore covered .env for exactly this reason while leaving the
# file that holds the actual data.
w=$(workdir); (cd "$w" && "$NP" db >/dev/null 2>&1)
p="$w/db"
mkdir -p "$p/api"
: > "$p/api/app.db"; : > "$p/api/app.db-wal"; : > "$p/api/app.db-shm"
: > "$p/data.sqlite"; : > "$p/data.sqlite3"
(cd "$p" && git add -A >/dev/null 2>&1)
assert_eq "no database file is staged" "0" \
  "$(cd "$p" && git diff --cached --name-only | grep -cE '\.(db|db-wal|db-shm|sqlite|sqlite3)$')"
assert_eq "and the skills are still all tracked" "$NSKILLS" \
  "$(cd "$p" && git ls-files | grep -c 'claude/skills/.*\.md')"

finish
