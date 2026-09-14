#!/usr/bin/env bash
# Negative tests for every check.sh rule.
#
# Each one breaks exactly one thing in a throwaway copy of the pack and asserts
# that check.sh both fails AND names the right problem. The message half is not
# decoration: "it exited non-zero" is also satisfied by a typo in the command,
# which is how a negative test comes to pass for a reason nobody intended.
#
# These were all run once by hand, at the moment each rule was written. That is
# the part this file replaces - a rule can now regress and something will say so.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

lint() { (cd "$1" && ./check.sh); }

section "check.sh passes on the pack as it stands"
assert_ok "clean tree lints green" lint "$REPO"

section "rule 1 - frontmatter"
r=$(fresh_repo); printf '# no frontmatter\n' > "$r/skills/verify.md"
assert_refuses "missing frontmatter is caught" "missing frontmatter" lint "$r"

r=$(fresh_repo); printf -- '---\nname: verify\n' > "$r/skills/verify.md"
assert_refuses "unterminated frontmatter is caught" "unterminated frontmatter" lint "$r"

section "rule 2 - name matches filename"
r=$(fresh_repo); sed -i 's/^name: verify$/name: verifyy/' "$r/skills/verify.md"
assert_refuses "name disagreeing with filename is caught" "!= filename" lint "$r"

section "rule 3 - description present"
r=$(fresh_repo); sed -i '/^description:/d' "$r/skills/verify.md"
assert_refuses "missing description is caught" "missing description" lint "$r"

section "rule 4 - no tool-specific references"
r=$(fresh_repo); printf '\nThen run /build to continue.\n' >> "$r/skills/verify.md"
assert_refuses "a /skill reference is caught" "tool-specific reference" lint "$r"

section "rule 5 - no retired names"
r=$(fresh_repo); printf '\nHand off to `idea` when done.\n' >> "$r/skills/verify.md"
assert_refuses "a retired name is caught" "not a skill in this pack" lint "$r"

section "rule 6 - step headings in order"
r=$(fresh_repo)
python3 - "$r/skills/verify.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); s = p.read_text()
# swap the first two step headings so they run 2, 1, 3...
nums = re.findall(r'^## Step (\d+)', s, re.M)
assert len(nums) >= 2, nums
s = s.replace(f'## Step {nums[0]} ', 'ZZTMP ', 1)
s = s.replace(f'## Step {nums[1]} ', f'## Step {nums[0]} ', 1)
s = s.replace('ZZTMP ', f'## Step {nums[1]} ', 1)
p.write_text(s)
PY
assert_refuses "out-of-order steps are caught" "step headings run" lint "$r"

section "rule 7 - every skill is reachable"
r=$(fresh_repo)
cp "$r/skills/verify.md" "$r/skills/orphaned.md"
sed -i 's/^name: verify$/name: orphaned/' "$r/skills/orphaned.md"
assert_refuses "an unrouted skill is caught" "unreachable" lint "$r"

# The bug this rule was written for: check.sh once died silently on a skill with
# no '## Step N' headings, and because reachability runs last a single stepless
# file disabled it for the whole pack - exit 1, no output at all.
r=$(fresh_repo)
printf -- '---\nname: stepless\ndescription: "A skill with no numbered steps at all."\n---\n\n# stepless\n\n## Before you start\n\nNothing.\n' > "$r/skills/stepless.md"
assert_refuses "a stepless skill still reports, not dies silently" "unreachable" lint "$r"

section "rule 8 - every script is referenced, and every named script exists"
r=$(fresh_repo); printf '#!/usr/bin/env bash\necho hi\n' > "$r/unreferenced.sh"; chmod +x "$r/unreferenced.sh"
assert_refuses "an unrouted script is caught" "nothing references it" lint "$r"

r=$(fresh_repo); printf '\nRun `./imaginary.sh` to start.\n' >> "$r/README.md"
assert_refuses "a named-but-absent script is caught" "not a script in this repo" lint "$r"

section "rule 9 - board fields have writers"
r=$(fresh_repo)
# A field only orchestrate names is the `Blocked on:` bug: four readers, no writer.
for f in "$r"/skills/*.md; do
  case "$(basename "$f")" in orchestrate.md) continue ;; esac
  sed -i 's/Blocked on:/Blocked-on-x:/g' "$f"
done
assert_refuses "a field with no writer is caught" "has no writer" lint "$r"

# Rule 9 finds the example by the "Each status file:" anchor. Rename the anchor
# and the rule has nothing to iterate over - which must fail loudly rather than
# check zero fields and report green. That silent-pass shape is what made rule 7
# useless for a year.
r=$(fresh_repo)
sed -i 's/^Each status file:$/Each part file:/' "$r/template/blueprint/orchestration.md"
assert_refuses "a missing example block fails loudly" "rule 9 is not checking anything" lint "$r"

section "rule 10 - preconditions"
r=$(fresh_repo); sed -i '/^## Before you start$/d' "$r/skills/verify.md"
assert_refuses "a missing precondition heading is caught" "no '## Before you start'" lint "$r"

r=$(fresh_repo)
python3 - "$r/skills/progress.md" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
p.write_text(s.replace('\n## ', '\n## Before you start\n\nNothing.\n\n## ', 1))
PY
assert_refuses "an exempt skill that grew one is caught" "on the exempt list" lint "$r"

section "rule 11 - frontmatter within host limits"
r=$(fresh_repo)
python3 - "$r/skills/verify.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); s = p.read_text()
p.write_text(re.sub(r'^description:.*$', 'description: "' + 'x'*1100 + '"', s, count=1, flags=re.M))
PY
assert_refuses "an over-length description is caught" "over the 1024 limit" lint "$r"

r=$(fresh_repo)
mv "$r/skills/verify.md" "$r/skills/Verify_X.md"
sed -i 's/^name: verify$/name: Verify_X/' "$r/skills/Verify_X.md"
assert_refuses "a non-conforming name is caught" "lowercase alphanumeric" lint "$r"

section "rule 12 - state files have declared writers"
r=$(fresh_repo)
python3 - "$r/template/AGENTS.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); s = p.read_text()
# drop the coding-standards row from the state/writer table
p.write_text(re.sub(r'^\|.*coding-standards\.md.*\|\s*$\n', '', s, count=1, flags=re.M))
PY
assert_refuses "a read file with no table row is caught" "no row in the state/writer table" lint "$r"

# The rule that once could not fail. This is the variant that caught it: the
# message printed and the exit code was still 0, because `fail` ran in a
# subshell created by a pipe into `while read`.
r=$(fresh_repo)
python3 - "$r/template/AGENTS.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); s = p.read_text()
p.write_text(re.sub(r'(\|[^|\n]*coding-standards\.md[^|\n]*\|[^|\n]*\|)([^|\n]*)\|',
                    r'\1 `rollback` |', s, count=1))
PY
assert_refuses "a declared writer that never writes is caught" "never names it" lint "$r"

r=$(fresh_repo)
python3 - "$r/template/AGENTS.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); s = p.read_text()
p.write_text(re.sub(r'^\|.*\|\s*$\n', '', s, flags=re.M))
PY
assert_refuses "a missing state table fails loudly" "rule 12 is not checking anything" lint "$r"

section "rule 13 - product-root files are named as such"
# The path class, long recorded as unlintable: a skill running inside
# a part reads `blueprint/x.md`, which there means that part's directory, while
# the file lives at the product root. Six recurrences - and the last found five
# skills reading a product plan that does not exist in a part at all, including
# `host`, which reads it to decide whether to spend money.
#
# Lintable once the product-level files are declared, the same move that made
# rules 9 and 12 possible.
r=$(fresh_repo)
python3 - "$r/skills/host.md" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
p.write_text(s.replace("`AGENTS.md` records `Product root:`", "somewhere records the root"))
PY
assert_refuses "a skill naming product-root state without the note is caught" \
  "without saying where it resolves" lint "$r"

# A rule that silently stops applying is worse than no rule - the failure that
# made rule 7 useless for a year and shipped rule 12 unable to fail.
r=$(fresh_repo)
python3 - "$r/template/AGENTS.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); s = p.read_text()
p.write_text(re.sub(r'<product root>/[A-Za-z0-9_./-]+', 'the file', s))
PY
assert_refuses "an empty product-root declaration fails loudly" \
  "rule 13 is not checking anything" lint "$r"

section "an exempt list cannot name a skill that does not exist"
# Rule 7's entry-point list still said `idea` after the rename to `ideate`. Dead
# config that hides what it was meant to exempt: the entry point was being
# checked by a rule it is exempt from, and passed only because other skills
# happen to route to it. The rename updated rule 10's list and not this one.
r=$(fresh_repo)
python3 - "$r/check.sh" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
p.write_text(s.replace('entry_points="ideate setup autopilot"',
                       'entry_points="idea setup autopilot"'))
PY
assert_refuses "a stale name in the entry-point list is caught" \
  "which is not a skill" lint "$r"

r=$(fresh_repo)
python3 - "$r/check.sh" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); s = p.read_text()
# Appended to whatever the list currently is, never to a copy of it. This test
# hardcoded the literal list, so removing `ideate` from it made the replace a
# silent no-op: check.sh was never modified, the bogus name was never inserted,
# and the test reported a failure to detect something that was never there.
s2 = re.sub(r'^(exempt_preconditions=")([^"]*)(")$', r'\1\2 gone\3', s, count=1, flags=re.M)
assert s2 != s, "exempt_preconditions assignment not found - the test needs updating"
p.write_text(s2)
PY
assert_refuses "and in the preconditions list" \
  "which is not a skill" lint "$r"

section "rule 14 - a decision skill says what happens when the decision exists"
# `ideate` assumed greenfield and would have erased the `- [x]` marks that are
# the resume mechanism. Three more had the same shape: `architect` never said
# re-deciding a layout after scaffold moves every file - the pack knew, and said
# it in `autopilot` instead - `prototype` never said a second design.md can
# describe a look the code does not have, and `stack` sent two different
# situations to one wrong answer.
#
# The list IS the rule. A fifth decision-writing skill has to be added to it
# deliberately, and that is the moment someone asks the question this forces.
r=$(fresh_repo)
python3 - "$r/skills/architect.md" <<'RULE14'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
i = s.index('**If the Architecture section is already filled')
j = s.index('## Input')
p.write_text(s[:i] + s[j:])
RULE14
assert_refuses "a decision skill silent about re-deciding is caught" \
  "never say what happens when that decision already exists" lint "$r"

# A declared list naming a skill that does not exist is dead config, and it hides
# the thing it was meant to check - the defect the other two lists already had.
r=$(fresh_repo)
python3 - "$r/check.sh" <<'RULE14'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s2 = re.sub(r'^(decision_skills=")([^"]*)(")$', r'\1\2 gone\3', s, count=1, flags=re.M)
assert s2 != s, 'decision_skills assignment not found - the test needs updating'
p.write_text(s2)
RULE14
assert_refuses "a stale name in the decision list is caught" \
  "which is not a skill" lint "$r"

section "rule 15 - a declared mode is named in the description"
# The description is what an agent matches a request against, so a mode missing
# from it is reachable only by someone who already knows it exists. `docs
# --check` was exactly that - its own Input row, its own section, and a question
# the skill says nothing else in this workflow asks - invisible to every agent
# choosing a skill. The Input tables ARE the declaration here, so no list.
r=$(fresh_repo)
python3 - "$r/skills/docs.md" <<'RULE15'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
i = s.index(' With --check, audits')
j = s.index(' Use when the user runs `docs`')
p.write_text(s[:i] + s[j:])
RULE15
assert_refuses "a mode dropped from the description is caught" \
  "never names it in the description" lint "$r"

# Five skills have an Input table with no backticked argument rows. Under
# `set -euo pipefail` the empty grep aborted check.sh with exit 1 and no output
# at all - a linter that finds nothing and a linter that died look identical.
assert_ok "a skill whose Input table has no argument rows does not kill the run" \
  bash -c 'out=$("$1/check.sh" 2>&1); rc=$?; [ "$rc" -eq 0 ] && [ -n "$out" ]' _ "$REPO"

finish
