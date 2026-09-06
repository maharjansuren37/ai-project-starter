#!/usr/bin/env bash
# Invariants that span files, which is where every serious defect in this pack
# has come from. The linter checks files one at a time and cannot see any of
# these; each one below is a bug that actually shipped here.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$REPO" || exit 1

section "the loop order agrees everywhere it is declared"
# Reconciled across ten declaration sites when `ci` moved after `scaffold`, and
# `host` still carried the old chain - missed because that sweep counted chains
# containing `ideate` or `scaffold`, and host's starts at `ci`. A check whose
# matching rule excludes the case it exists to find.
chains=$(grep -rhoE '[`a-z]+ *(->|→)[ `a-z→>-]+' --include='*.md' skills/ template/ docs/ README.md 2>/dev/null \
         | tr -d '`' | sed 's/  */ /g')
assert_eq "nothing declares scaffold -> context (ci is between them)" "0" \
  "$(printf '%s\n' "$chains" | grep -c 'scaffold -> context' || true)"
assert_eq "nothing declares ship -> ci (ci moved before the build loop)" "0" \
  "$(printf '%s\n' "$chains" | grep -c 'ship -> ci' || true)"
assert_eq "nothing declares ci -> preflight" "0" \
  "$(printf '%s\n' "$chains" | grep -c 'ci -> preflight' || true)"
assert_eq "every ideate chain is the same one" "1" \
  "$(printf '%s\n' "$chains" | grep -oE 'ideate -> stack -> architect -> scaffold -> ci -> context' | sort -u | wc -l | tr -d ' ')"

section "every declared transition is a real handoff, not just a declaration"
# Four transitions were broken at once: `stack`->`architect`, `scaffold`->`ci`,
# `ci`->`context` and `review`->`ship`. Every chain in every file agreed, and
# following the loop the way a user does dead-ended at scaffold and again at ci.
#
# Cause: when `ci` moved from after `ship` to after `scaffold`, the sweep
# reconciled the eight *declaration* sites - headers, README, guides - and not
# the handoffs. A declaration says where a skill sits; a handoff is what makes
# the next one get run. The linter cannot tell them apart: rule 7 is satisfied
# by any mention, including one inside a chain diagram.
#
# So this checks the successor is named in prose, outside the "Where this sits"
# block that every skill already has.
broken=""
while read -r from to; do
  [ -n "$from" ] || continue
  # Strip the chain diagrams, not a line range. "Where this sits:" is followed
  # by a BLANK line, so a /start/,/^$/ range ended before the diagram and left
  # it in - the successor matched its own declaration and this test could not
  # fail. Found by removing a real handoff and watching it stay green.
  body=$(grep -vE '^[[:space:]]+.*(->|→)' "skills/$from.md" | grep -v '^Where this sits:')
  # Herestring, never a pipe into `grep -q`. grep -q exits on the first match and
  # closes the pipe, the writer takes SIGPIPE, and `set -o pipefail` in lib.sh
  # turns that into a failed pipeline *even though the match succeeded* - so this
  # reported missing handoffs at random, three runs in ten, a different pair each
  # time. Same shape as the rule 12 bug: correct logic, wrong exit status, and
  # only visible because the assertion was run enough times to catch it.
  grep -q -- "\`$to\`" <<< "$body" || broken="$broken $from->$to"
#
# The population is the whole declared loop, not only the plan-and-build path.
# It stopped at `review ship` when it was written, so the operate phase and the
# multi-part path were never checked - and both had a broken transition sitting
# in them: `ship` never named `preflight` at all, while the README diagram,
# template/AGENTS.md, `preflight` and `host` all declared `ship -> preflight`,
# and `deploy` gates production on preflight having returned go. `integrate`
# declared `-> deploy` and ended without pointing anywhere.
#
# That is the third time a check here has had a matching rule that excluded the
# case it exists to find, after `host`'s chain starting at `ci` and the backtick
# sweep. When a transition is added to any chain, add it here too.
done <<'PAIRS'
setup ci
ideate stack
stack architect
architect scaffold
scaffold ci
ci context
context spec
spec build
build verify
verify review
review ship
ship preflight
preflight host
host deploy
deploy monitor
monitor debug
architect orchestrate
ship integrate
integrate deploy
PAIRS
assert_eq "every loop transition hands off in prose" "" "$broken"

section "no skill refers to state without naming a path"
# Eight skills said "the plan", "the standards", "the findings ledger" with no
# path. In a multi-part product "the plan" is the product's and "the standards"
# are the part's own, and the wrong answer is silently plausible.
for phrase in "the findings ledger" "the coding standards" "the quality bar"; do
  hits=$(grep -rln "$phrase" skills/ 2>/dev/null | while read -r f; do
           grep -q 'blueprint/' "$f" || echo "$f"
         done | wc -l | tr -d ' ')
  assert_eq "\"$phrase\" always appears with a blueprint path" "0" "$hits"
done

section "every skill is named in at least one document"
missing=""
for f in skills/*.md; do
  n=$(basename "$f" .md)
  grep -rqlF "\`$n\`" README.md docs/ template/AGENTS.md 2>/dev/null || missing="$missing $n"
done
assert_eq "no skill is undocumented" "" "$missing"

section "every markdown link resolves"
# Scoped to the documents meant to be navigated. dev-notes/ is excluded on
# purpose: it quotes paths as prose - including `../../../etc/passwd` from the
# traversal test - and a link checker that reads those as links reports a false
# positive, which is exactly the defect the link checker itself was fixed for.
broken=""
for src in README.md docs/*.md; do
  base=$(dirname "$src")
  for target in $(grep -oE '\]\([^)]+\)' "$src" 2>/dev/null | sed 's/^](//; s/)$//' \
                  | grep -vE '^https?:|^#|^mailto:' | sed 's/#.*//'); do
    [ -n "$target" ] || continue
    [ -e "$base/$target" ] || [ -e "$target" ] || broken="$broken $src->$target"
  done
done
assert_eq "no broken relative links in README or docs" "" "$broken"

section "the counts in the docs match reality"
# Retargeted from the pack's own build notes, which are not in this repo - they
# are a working diary naming real projects and hosts. A test that reads a file
# only the author has passes for them and fails for everyone else, which is
# worse than no test.
assert_eq "README's skill count is right" \
  "$(ls skills/*.md | wc -l | tr -d ' ')" \
  "$(grep -oE '[0-9]+ skills for Claude Code' README.md | grep -oE '^[0-9]+')"
assert_eq "the linter rule count in the docs is right" \
  "$(grep -oE '^# [0-9]+ ?[.-] ' check.sh | grep -oE '[0-9]+' | sort -n | tail -1)" \
  "$(grep -ohE '[0-9]+ rules' README.md AGENTS.md CLAUDE.md | grep -oE '[0-9]+' | sort -u)"
assert_eq "every guide in docs/ is named in the entry points" "" \
  "$(for g in docs/*.md; do n=$(basename "$g"); grep -qF "$n" README.md AGENTS.md CLAUDE.md || echo " $n"; done)"

section "the retired list covers every rename"
# Renaming without adding the old name to `retired` is what leaves the gap;
# the rule is not the gap.
# The list lives in lib/retired-names - check.sh (rule 5) and install.sh
# (pruning a project's old skills on upgrade) both read it from there.
RETIRED=$(grep -v '^#' lib/retired-names | grep -v '^[[:space:]]*$')
assert_ok "'idea' is retired" bash -c 'grep -qx idea lib/retired-names'
assert_eq "no retired name is also a live skill" "0" \
  "$(for r in $RETIRED; do [ -f "skills/$r.md" ] && echo x; done | wc -l | tr -d ' ')"
assert_fails "the list is not empty" bash -c '[ -z "$(grep -v "^#" lib/retired-names | grep -v "^[[:space:]]*$")" ]' 

section "the standards split by ownership"
# One file with a pack-owned half and a project-owned half is a file with two
# writers. install.sh only ever wrote a template file when absent, so the
# fundamentals never reached a project that already existed - `setup` found none
# and invented a thinner list of its own.
fu=template/blueprint/context/fundamentals.md
cs=template/blueprint/context/coding-standards.md
assert_ok "the pack owns fundamentals.md"      test -f "$fu"
assert_ok "it says edits there are overwritten" grep -qi 'overwritten' "$fu"
assert_ok "the project owns coding-standards"  grep -qi 'overwrites this file' "$cs"
assert_ok "each points at the other"           bash -c 'grep -q "coding-standards.md" '"$fu"' && grep -q "fundamentals.md" '"$cs"
assert_ok "the heading review audits exists"   grep -q '^## Standards this project follows' "$cs"
assert_ok "install.sh refreshes fundamentals"  grep -q 'blueprint/context/fundamentals.md' install.sh

# An existing project usually has standards already - a linter config, a
# CONTRIBUTING.md, an .editorconfig. setup merges with those rather than deriving
# a confident second version from the code that quietly disagrees with the team's
# own written rules.
assert_ok "setup looks for standards already written down" \
  bash -c "tr '\n' ' ' < skills/setup.md | grep -q 'CONTRIBUTING.md'"
assert_ok "setup defers to a tool over restating its rule" \
  bash -c "tr '\n' ' ' < skills/setup.md | tr -s ' ' | grep -q 'never restate the rule in prose'"
assert_ok "the template records where a rule came from" \
  grep -q '^## Where these rules come from' "$cs"
assert_ok "review follows the file out to what it references" \
  bash -c "tr '\n' ' ' < skills/review.md | tr -s ' ' | grep -q 'Follow the standards file out to what it points at'"
assert_eq "no duplicate section headings" "0" \
  "$(grep '^## ' "$cs" | sort | uniq -d | wc -l | tr -d ' ')"
assert_ok "scaffold writes the standards heading" grep -q 'Standards this project follows' skills/scaffold.md
# Matched against whitespace-collapsed text: the phrase is line-wrapped in
# setup.md, and a naive grep reports absent for something that is present. That
# is the backtick-sweep failure again - normalise before matching, or the check
# silently excludes the shape it is looking for.
assert_ok "setup writes it too" \
  bash -c "tr '\n' ' ' < skills/setup.md | tr -s ' ' | grep -q 'Standards this project follows'"

section "the honest-limits section names no skill as unrun"
# It went stale by a day once, naming three skills as never run after all three
# had run - and it is the section a reader trusts most, because a caveat that is
# out of date is indistinguishable from a current one. Every skill has now been
# run, so any such claim here is wrong by construction.
unproven=$(sed -n '/^## What is still unproven/,/^## /p' docs/anatomy.md \
  | awk '/^- /{if(b)print b; b=$0; next}
         /^[[:space:]]+[^[:space:]]/{b=b" "$0; next}
         {if(b)print b; b=""} END{if(b)print b}' | tr -s ' ')
assert_eq "no skill is described as never run" "" \
  "$(grep -i 'never been run\|never run' <<< "$unproven" | grep -oE '`[a-z-]+`' | tr -d '`' \
     | while read -r n; do [ -f "skills/$n.md" ] && echo " $n"; done)"
# Counted into a variable first. Interpolating $unproven into a `bash -c` string
# hangs: the text contains backticked skill names, which bash then treats as
# command substitution and waits on stdin for. Third time a test here has been
# broken by its own shell mechanics rather than by what it checks.
partly=$(grep -ci 'only part' <<< "$unproven" || echo 0)
assert_ok "the section still says what is only partly proven" test "$partly" -ge 1

section "ci proves a pipeline the way CI will see it"
# A project's .env supplies variables the runner will not have, so a local proof
# run with it present says nothing about whether the pipeline works - the same
# shape as a test that passes because the fixture was already there. Verified on
# a real repo: `npm run verify` needs only DATABASE_URL, and the hand-written
# workflow had set two more that nothing reads at build time.
assert_ok "ci proves without the local .env" \
  bash -c "tr '\n' ' ' < skills/ci.md | tr -s ' ' | grep -q 'without the local'"
assert_ok "ci proves from a clean install" \
  bash -c "tr '\n' ' ' < skills/ci.md | tr -s ' ' | grep -q 'from a clean dependency install'"
assert_ok "ci caches the dependency install" \
  bash -c "tr '\n' ' ' < skills/ci.md | tr -s ' ' | grep -qi 'Cache the dependency install'"

section "a configured check that gates nothing is reported"
# One project had ESLint configured and `npm run lint` outside `verify`, so
# no lint rule blocked anything. Twelve skills referenced "the verification
# command" and none asked whether it ran what the project actually had. The
# session found it by accident while writing a standards table.
assert_ok "ci checks the verify command is complete" \
  bash -c "tr '\n' ' ' < skills/ci.md | tr -s ' ' | grep -q 'runs what the project has configured'"
assert_ok "ci does not wire it in itself" \
  bash -c "tr '\n' ' ' < skills/ci.md | tr -s ' ' | grep -q 'do not wire it in from here'"
assert_ok "preflight names checks that exist but do not gate" \
  bash -c "tr '\n' ' ' < skills/preflight.md | tr -s ' ' | grep -q 'exist but do not gate'"

section "rollback's stop is a decision point, not the end of the skill"
# Step 2 said "stop" when a later feature depends on the target; Step 3 said
# "write the guarded spec". Nothing said which won - so for any entangled
# feature, which is the case the skill exists for, its headline deliverable was
# unreachable. A feature with no dependents barely needs a dependency review.
assert_ok "the stop is for a decision" \
  bash -c "tr '\n' ' ' < skills/rollback.md | tr -s ' ' | grep -q 'stop for a decision, not the end of the skill'"
assert_ok "and abandoning is a real outcome" \
  bash -c "tr '\n' ' ' < skills/rollback.md | tr -s ' ' | grep -q 'an unusable spec is worse than none'"
assert_ok "unrelated work in the same commit is excluded" \
  bash -c "tr '\n' ' ' < skills/rollback.md | tr -s ' ' | grep -q 'more than its headline'"
assert_ok "the data question is asked separately from the code" \
  bash -c "tr '\n' ' ' < skills/rollback.md | tr -s ' ' | grep -q 'Reversing code and reversing a schema are different'"
assert_ok "and it routes the schema half to migrate" \
  bash -c "tr '\n' ' ' < skills/rollback.md | tr -s ' ' | grep -q '.migrate. owns this'"

section "needs-you lines can be closed, not only opened"
# Six skills wrote to needs-you.md, three read it, and nothing ever closed a
# line - the mirror of the `Blocked on:` bug, which had readers and no writer.
# The file could only grow, so every item stayed open forever and `preflight`
# treats an open required line as a blocker: a requirement met months ago would
# have failed a release permanently.
ny=template/blueprint/context/needs-you.md
assert_ok "the file says who closes a line"      grep -q '^## Closing a line' "$ny"
assert_ok "the closer is the skill that needed it" \
  bash -c "tr '\n' ' ' < $ny | tr -s ' ' | grep -q 'skill that would have needed it closes it'"
assert_ok "prepare is excluded from closing" \
  bash -c "tr '\n' ' ' < $ny | tr -s ' ' | grep -q '.prepare. never closes anything'"
assert_ok "preflight verifies before calling a line a blocker" \
  bash -c "tr '\n' ' ' < skills/preflight.md | tr -s ' ' | grep -q 'check each open line is still open'"
assert_ok "progress reports the person's side too" \
  bash -c "tr '\n' ' ' < skills/progress.md | tr -s ' ' | grep -q 'Report both sides of the work'"

section "scaffold checks the component, not just the toolchain"
# `dotnet --version` reported 10.0.110, `dotnet new console` built, and
# `dotnet new webapi` created a project that could not build - ASP.NET Core is a
# separate package. The scaffolder exited 0 while producing something broken,
# which is the Vite lesson in a different ecosystem five days later.
assert_ok "it says an SDK is not one thing" \
  bash -c "tr '\n' ' ' < skills/scaffold.md | tr -s ' ' | grep -q 'An SDK is not one thing'"
assert_ok "it distinguishes running from building" \
  bash -c "tr '\n' ' ' < skills/scaffold.md | tr -s ' ' | grep -q 'running and building need different ones'"
assert_ok "it covers python having no pip" \
  bash -c "tr '\n' ' ' < skills/scaffold.md | tr -s ' ' | grep -q 'working interpreter and no .pip.'"
assert_ok "and states the generic form" \
  bash -c "tr '\n' ' ' < skills/scaffold.md | tr -s ' ' | grep -q 'in the shape the project will actually take'"

section "OWASP is cited by edition, not from memory"
# An agent recalling the 2021 list never looks for A03 Software Supply Chain
# Failures or A10 Mishandling of Exceptional Conditions - both new in 2025.
assert_eq "no unversioned 'OWASP Top 10' outside review's own explanation" "0" \
  "$(grep -rn 'OWASP Top 10' skills/ template/ | grep -vc 'Top 10:2025\|Top 10 2025\|renumbered')"

section "every test file runs all of itself"
# `finish` prints the summary and exits, so anything appended after it never
# runs - and the suite still reports green, because the assertions that would
# have failed were never reached. Hit while adding tests to this suite: 16 new
# assertions sat below `finish` and the count did not move.
#
# A test that cannot run is the same defect as a rule that cannot fail, which
# this repo has now recorded four times.
for tf in tests/test-*.sh; do
  last=$(grep -vE '^\s*(#.*)?$' "$tf" | tail -1 | tr -d ' ')
  assert_eq "$(basename "$tf") ends with finish" "finish" "$last"
done

section "the plan template has a home for everything ideate is told to write"
# `ideate` Step 3 named five things to write into project-plan.md and the
# template had sections for three. Constraints and the deferred list had nowhere
# to go - and `stack` Step 1 asks for the constraints next, so the answer was
# re-asked in the same sitting and lost entirely between sessions. A writer with
# nowhere to write is the reader-without-writer defect from the other side.
plan="template/blueprint/project-plan.md"
assert_ok "the template has a Constraints section" \
  grep -qE '^## [0-9]+\. Constraints' "$plan"
assert_ok "and a deliberately-deferred section" \
  grep -qE '^## [0-9]+\. Deliberately deferred' "$plan"
assert_ok "ideate points at the constraints section by number" \
  bash -c "tr '\n' ' ' < skills/ideate.md | tr -s ' ' | grep -q 'constraints\*\* (section 10)'"
assert_ok "ideate points at the deferred section by number" \
  bash -c "tr '\n' ' ' < skills/ideate.md | tr -s ' ' | grep -q '(section 11)'"
# The other half: stack must read what ideate wrote instead of asking again.
assert_ok "stack reads the recorded constraints rather than re-asking" \
  bash -c "tr '\n' ' ' < skills/stack.md | tr -s ' ' | grep -q 'Read section 10 of'"
# And every numbered section a skill names must exist in the template.
tmpl=$(grep -oE '^## [0-9]+\.' "$plan" | grep -oE '[0-9]+' | tr '\n' ' ')
missing=""
for n in $(grep -ohE 'section [0-9]+' skills/*.md | grep -oE '[0-9]+$' | sort -un); do
  grep -qw "$n" <<< "$tmpl" || missing="$missing $n"
done
assert_eq "every plan section a skill names exists" "" "$missing"

section "a version is checked against the runtime that is installed"
# `stack` settled "the runtime" as a choice and never compared it to the machine.
# `scaffold` compares it as a fact - one skill after the user approved a stack.
# On a real run Node 20.18.1 was one patch below what current Vite, its React
# plugin and current Vitest all require, so "Vite 8, current stable" read
# perfectly and could not be built.
assert_ok "stack checks the named version against the installed runtime" \
  bash -c "tr '\n' ' ' < skills/stack.md | tr -s ' ' | grep -q 'Check the version you are about to name against the runtime that is actually installed'"
assert_ok "and offers both remedies rather than picking one silently" \
  bash -c "tr '\n' ' ' < skills/stack.md | tr -s ' ' | grep -q 'upgrade the runtime'"
# scaffold's own remedies do not cover the case where the plan named the
# impossible version - pinning "to what the plan said" is then the bug.
assert_ok "scaffold routes back to stack when the plan named an unrunnable version" \
  bash -c "tr '\n' ' ' < skills/scaffold.md | tr -s ' ' | grep -q 'Route back to .stack.'"
assert_ok "and does not pick a replacement version itself" \
  bash -c "tr '\n' ' ' < skills/scaffold.md | tr -s ' ' | grep -q 'Do not choose a replacement version'"

section "product-level state is named as such wherever it is read"
# `architect` runs at the product root and writes quality-bar.md there. `spec`,
# `verify`, `review`, `preflight` and `monitor` all run *inside a part*, where an
# unqualified `blueprint/` means that part's own directory - so all five read a
# file nothing wrote, and all five guard with "if it exists", which turns it into
# silence rather than an error. The unlintable path class, sixth instance.
#
# The fix reuses the mechanism that already handles project-plan.md: one note
# naming what lives at the product root, carried by everything that touches it.
for n in spec verify review preflight monitor architect setup; do
  assert_ok "$n names quality-bar as product-root state" \
    grep -q 'the bar the whole product is held to' "skills/$n.md"
done
assert_ok "architect writes the qualified path, not a copy per part" \
  grep -q 'product root>/blueprint/context/quality-bar.md' skills/architect.md
assert_ok "and says explicitly not to write one per part" \
  bash -c "tr '\n' ' ' < skills/architect.md | tr -s ' ' | grep -q 'do not write a copy into each part'"

section "splitting a project across parts leaves nothing without a writer"
# `ideate` writes the only initial item set and runs once, at the product root.
# The conversion moves it into --existing and seeds the others empty, so the
# other part's build-plan has four readers and no writer - `spec` run there
# reports "nothing is queued" while its whole surface is unbuilt.
assert_ok "architect says the build plan must be split per part" \
  bash -c "tr '\n' ' ' < skills/architect.md | tr -s ' ' | grep -q 'split the build plan across the parts'"
assert_ok "and says why nothing else will do it" \
  bash -c "tr '\n' ' ' < skills/architect.md | tr -s ' ' | grep -q 'only skill that writes an initial item set'"
assert_ok "the converter reports what it moved" \
  grep -q 'written before there were parts' convert-to-parts.sh
assert_ok "and does not try to split it itself" \
  grep -q 'Nothing here splits these' convert-to-parts.sh

section "needs-you lines land where prepare will read them"
# `stack` writes needs-you.md and, in the normal flow, runs before parts exist -
# so the conversion carries the file into --existing and the other part never
# sees it. Run at an already-split product root it is worse: `prepare`,
# `progress` and `preflight` only read the part they are run in, so a line at
# the root is written to nobody.
assert_ok "stack says where a needs-you line goes in a split product" \
  bash -c "tr '\n' ' ' < skills/stack.md | tr -s ' ' | grep -q 'needs-you.md. is part-local'"
assert_ok "and names who would otherwise never see it" \
  bash -c "tr '\n' ' ' < skills/stack.md | tr -s ' ' | grep -q 'only ever read the part they are run in'"

section "anatomy's state table counts match the skills"
# Two reader counts in that table said "10 skills" - one meant 13 and the other
# meant everything touching the file rather than its readers - and multi-part.md
# disagreed with anatomy about the same file. A count nobody can check is the
# drift this repo has now recorded five times, and the state table is the thing
# a maintainer reads to decide where a new file belongs.
#
# Blockquote lines are stripped first: the product-root note names project-plan
# and quality-bar, so every skill carrying it would otherwise count as a reader.
bad=""
while IFS= read -r row; do
  file=$(sed 's/^| `\([^`]*\)`.*/\1/' <<< "$row")
  claim=$(grep -oE '\| [0-9]+ skills \|' <<< "$row" | grep -oE '[0-9]+')
  [ -n "$claim" ] || continue
  writers=$(awk -F'|' '{print $4}' <<< "$row" | grep -oE '`[a-z-]+`' | tr -d '`')
  real=0
  for sk in skills/*.md; do
    n=$(basename "$sk" .md)
    grep -qx "$n" <<< "$writers" && continue
    grep -v '^>' "$sk" | grep -qF -- "$file" && real=$((real + 1))
  done
  [ "$claim" = "$real" ] || bad="$bad $file(says $claim, is $real)"
done <<< "$(grep -E '^\| `blueprint/[^`]*` \|.*\| [0-9]+ skills \|' docs/anatomy.md)"
assert_eq "every \"N skills\" reader count in anatomy is real" "" "$bad"

# And the two documents must not disagree about the same file.
assert_eq "multi-part.md agrees on how many skills touch current-work" \
  "$(grep -lF 'current-work.md' skills/*.md | wc -l | tr -d ' ')" \
  "$(grep -oE 'current-work\.md` is read or written by [0-9]+' docs/multi-part.md | grep -oE '[0-9]+$')"

finish
