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
# The path class, which status.md recorded as unlintable: a skill running inside
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
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
p.write_text(s.replace('exempt_preconditions="ideate setup progress preflight debug docs prepare"',
                       'exempt_preconditions="ideate setup progress preflight debug docs prepare gone"'))
PY
assert_refuses "and in the preconditions list" \
  "which is not a skill" lint "$r"

finish
