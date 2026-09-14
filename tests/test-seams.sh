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
  "$(printf '%s\n' "$chains" | grep -oE 'ideate -> architect -> stack -> layout -> scaffold -> ci -> context' | sort -u | wc -l | tr -d ' ')"
# The order changed: architecture before technology. Nothing may still declare
# the old direction, in any file - a stale chain in one skill is how a reader
# learns the wrong loop and never finds out.
assert_eq "nothing still declares stack -> architect" "0" \
  "$(printf '%s\n' "$chains" | grep -c 'stack -> architect' || true)"
assert_eq "nothing declares stack -> scaffold (layout is between them)" "0" \
  "$(printf '%s\n' "$chains" | grep -c 'stack -> scaffold' || true)"

section "nothing claims architect decides the physical layout"
# `layout` was split out of `architect` on 2026-09-08. Nine files still said
# "the layout `architect` chose" afterwards - every one of them individually
# readable, and together they teach a loop that no longer exists. The linter
# cannot see it: each is a true-looking sentence about a skill that exists.
#
# The split is the point. `architect` decides how many deployable parts and why;
# `layout` decides what the directories are called. A file that attributes the
# second to `architect` sends the reader to the wrong skill to change it.
stale=$(grep -rniE '(layout|directorie?s?) [^.]{0,40}`?architect`? (chose|chooses|decides|decided|recorded)|`?architect`? [^.]{0,30}(decides|decided|chose|chooses) [^.]{0,20}(code )?layout' \
        --include='*.md' skills/ template/ docs/ README.md 2>/dev/null || true)
assert_eq "no file attributes the directory layout to architect" "" "$stale"

section "a cold session is told where to start and what is unverified"
# The context that produced this pack's largest change lived only in a
# conversation, and conversations are cleared. Two things had to survive it:
#
#   - CLAUDE.md is the first file a session reads, and it pointed at the README,
#     anatomy and decisions - not at status.md, which is where "the tree is
#     uncommitted, run the suite before touching anything" is written.
#   - The reorder's headline result - a technology eliminated by the quality bar
#     rather than by taste - was produced by a session that KNEW what the reorder
#     was meant to demonstrate, and wrote the bar. Repeating that as evidence
#     without the caveat is how a promising result becomes a settled one.
assert_ok "CLAUDE.md sends a cold session to status.md first" \
  bash -c "tr '\n' ' ' < CLAUDE.md | tr -s ' ' | grep -qF 'Start with \`dev-notes/status.md\`'"
# AGENTS.md is the same file for every tool that is not Claude Code - opencode,
# Codex, Cursor all read it first - and it still pointed at the README after
# CLAUDE.md was fixed. Half a fix reads exactly like a whole one: the claim
# "Claude Code reads CLAUDE.md, which says the same things" sits in AGENTS.md's
# own opening, so nothing about the file looks stale.
assert_ok "AGENTS.md sends a cold session to status.md first" \
  bash -c "tr '\n' ' ' < AGENTS.md | tr -s ' ' | grep -qF 'Start with \`dev-notes/status.md\`'"
assert_ok "status.md says to check for uncommitted work before anything else" \
  bash -c "sed -n '1,40p' dev-notes/status.md | grep -qF 'is not committed'"
assert_ok "and says what to run to confirm the tree is intact" \
  bash -c "sed -n '1,40p' dev-notes/status.md | grep -qF 'tests/run.sh'"
# The first version of that instruction pinned an assertion COUNT, and went
# stale within the same session that wrote it - the suite grew by six before the
# day ended. A tripwire that fails on every commit is one people learn to skip.
assert_eq "the tripwire is zero failures, not a total that goes stale" "0" \
  "$(sed -n '1,40p' dev-notes/status.md | grep -cE '[0-9]{3} assertions' || true)"
assert_ok "the confound on the reorder's headline result is recorded" \
  bash -c "tr '\n' ' ' < dev-notes/status.md | tr -s ' ' | grep -qF 'the same session wrote that bar' || tr '\n' ' ' < dev-notes/status.md | tr -s ' ' | grep -qF 'same session wrote that bar'"
assert_ok "and says not to cite it as evidence the reorder works" \
  bash -c "tr '\n' ' ' < dev-notes/status.md | tr -s ' ' | grep -qF 'do not cite it as evidence'"
assert_ok "and records that the reorder traded seams rather than removing them" \
  bash -c "tr '\n' ' ' < dev-notes/status.md | tr -s ' ' | grep -qF 'Better seams, not fewer'"

section "the public notes stand on their own"
# The pack's working diary was gitignored because it names real projects and a
# domain - and this suite and both entry points read it. So a clone failed its
# own tests and sent a cold session to a file that was not there, while every
# check passed here, where the file existed. Found on 2026-09-14 by running the
# suite from a copy of the tree with the ignored files left out, never by
# reading. The fix split the diary: status.md and coverage.md are public and
# tracked, and the diary itself is dev-notes/journal.md, local only.
_is_git=no
git rev-parse --git-dir >/dev/null 2>&1 && _is_git=yes
_ignored() {
  if [ "$_is_git" = yes ]; then git check-ignore -q --no-index -- "$1"
  else grep -qxF -- "$1" .gitignore; fi
}
# journal.md is the one deliberate exception: it is ignored on purpose, and read
# below only when it exists.
_ignored_reads=""
for _p in $(grep -ohE '(dev-notes|docs)/[a-z-]+\.md' tests/test-*.sh AGENTS.md CLAUDE.md \
            | sort -u | grep -vxF 'dev-notes/journal.md'); do
  _ignored "$_p" && _ignored_reads="$_ignored_reads $_p"
done
assert_eq "nothing the suite or the entry points read is gitignored" "" "$_ignored_reads"

# The other half: the public files must not carry what the diary was kept local
# to hold back. The names can only be listed in the diary itself - a list here
# would publish them - so this runs only where the diary exists, which is the
# machine the pack is published from. Elsewhere it says it skipped, out loud.
if [ -f dev-notes/journal.md ]; then
  _names=$(awk '/^## Names kept out of the public files/{f=1; next}
                f && /^#/{exit}
                f && /^    [^ ]/{sub(/^    /, ""); print}' dev-notes/journal.md)
  assert_eq "the journal declares the names to keep out" "yes" \
    "$([ -n "$_names" ] && echo yes || echo no)"
  if [ "$_is_git" = yes ]; then _public=$(git ls-files -co --exclude-standard)
  else _public=$(find . -type f -not -path './.git/*' | sed 's|^\./||'); fi
  _public=$(printf '%s\n' "$_public" | grep -vxF 'dev-notes/journal.md')
  _leaks=""
  for _n in $_names; do
    # shellcheck disable=SC2086
    _hits=$(grep -liwF -- "$_n" $_public 2>/dev/null | tr '\n' ' ')
    [ -n "$_hits" ] && _leaks="$_leaks $_n: $_hits"
  done
  assert_eq "no public file names a private project" "" "$_leaks"
else
  printf '  skip no public file names a private project - dev-notes/journal.md is local only and absent here\n'
fi

section "adopting an already multi-part repository has a documented route"
# Found by trying it on a real npm workspace (2026-09-08). The route existed and
# worked, and nothing said so: `convert-to-parts.sh` is documented and is the
# WRONG tool here - it converts a single project by moving everything into one
# part - while the right one needs `seed-product-root.sh`, mentioned once in a
# table of scripts and in no guide at all.
assert_ok "multi-part.md documents adopting an existing repository" \
  grep -q '^## Or adopt a repository that was already multi-part' docs/multi-part.md
assert_ok "and says convert-to-parts is the wrong tool for it" \
  bash -c "tr '\n' ' ' < docs/multi-part.md | tr -s ' ' | grep -qF 'is the wrong tool'"
assert_ok "and names seed-product-root.sh, which no guide mentioned before" \
  grep -q 'seed-product-root.sh' docs/multi-part.md
assert_ok "and warns both scripts need the same paths" \
  bash -c "tr '\n' ' ' < docs/multi-part.md | tr -s ' ' | grep -qF 'Pass the same paths to both scripts'"
assert_ok "and says a single-part install may be the better answer" \
  bash -c "tr '\n' ' ' < docs/multi-part.md | tr -s ' ' | grep -qF 'Consider whether you want this at all'"

section "verify --all does not read the archive directory README as an archive"
# The template ships a README.md in blueprint/history/{features,fixes,rollbacks}
# explaining the naming convention. `verify --all` is told to read "each file
# under" those directories - which includes it. An archive with no done-whens
# reports as a silent extra or a could-not-verify against a feature that does
# not exist, and neither invites a second look.
#
# Found by running `progress` on a real project and noticing the archive listing
# had one more entry than the project had items. `--all` has never been run.
for d in features fixes rollbacks; do
  assert_exists "the template really does ship a README in history/$d" \
    "template/blueprint/history/$d/README.md"
done
assert_ok "verify --all is told to skip it" \
  bash -c "tr '\n' ' ' < skills/verify.md | tr -s ' ' | grep -qF 'that is not an archive'"
assert_ok "and names what an archive is actually called" \
  grep -q 'named .NN-title.md. for a feature' skills/verify.md

section "scaffold shapes the app for production, and preflight is not the first to ask"
# Found by running preflight on a real project (2026-09-08). Three things it
# flagged were cheap at scaffold and retrofits by then, and none of them need a
# server - so they are not `host`'s to provision, they are `scaffold`'s to shape:
#
#   - PORT, HOSTNAME and NODE_ENV were in no .env.example and no plan section.
#     `preflight` mandates a three-source merge to build that list; `scaffold`
#     did not, which GUARANTEES the gap rather than catching it.
#   - `pino` sat installed with zero call sites. Step 7 audited presence, not
#     use, so it passed every check the pack has.
#   - No security headers at all, and only `preflight` even mentioned them.
#
# The line held deliberately: provisioning production stays `host`'s, because it
# costs money and accounts. Shaping the app so it *can* be production does not.
assert_ok "scaffold builds the env list from three places, like preflight" \
  bash -c "tr '\n' ' ' < skills/scaffold.md | tr -s ' ' | grep -qF 'Build that list from three places'"
assert_ok "and says doing it only in preflight guarantees the gap" \
  bash -c "tr '\n' ' ' < skills/scaffold.md | tr -s ' ' | grep -qF 'guarantees the gap'"
assert_ok "and names what a framework reads without appearing in source" \
  grep -q 'PORT`, `HOSTNAME` and `NODE_ENV' skills/scaffold.md

assert_ok "scaffold sets the security headers it can" \
  bash -c "tr '\n' ' ' < skills/scaffold.md | tr -s ' ' | grep -qF 'set the security headers the framework has a place for'"
assert_ok "and refuses to invent a CSP" \
  grep -q 'Do not invent a Content-Security-Policy here' skills/scaffold.md
assert_ok "and requires the unset one be recorded, not silent" \
  bash -c "tr '\n' ' ' < skills/scaffold.md | tr -s ' ' | grep -qF 'look identical at the end and are not the same thing'"

assert_ok "scaffold's audit checks use, not just presence" \
  bash -c "tr '\n' ' ' < skills/scaffold.md | tr -s ' ' | grep -qF 'check each installed dependency has a call site'"
assert_ok "and says nothing else in the workflow does" \
  bash -c "tr '\n' ' ' < skills/scaffold.md | tr -s ' ' | grep -qF 'audits *use*, not presence, and nothing else'"

# The line that must NOT move: provisioning stays host's.
assert_eq "scaffold still does not provision a production environment" "0" \
  "$(grep -ci 'scaffold.*provision.*production\|create the production environment' skills/scaffold.md || true)"
assert_ok "and the development row is still the only environment scaffold writes" \
  grep -q 'It is the only environment' skills/scaffold.md

section "the pack says a mutation used to prove a test can itself be a no-op"
# Found by doing it (2026-09-08). A new test was "proven" by reversing an input
# array - but each element carried its own position and the query sorted by
# position, so the data came back identical and the test passed against code
# that was supposed to be broken. It looked exactly like a proven test.
#
# The runner already guards its own harness; nothing taught the practice. This
# is the one place a green result is most trusted and least examined.
assert_ok "CLAUDE.md says to check the break was real" \
  bash -c "tr '\n' ' ' < CLAUDE.md | tr -s ' ' | grep -qF 'check the break was real'"
assert_ok "and names the failure - a mutation that changes nothing" \
  bash -c "tr '\n' ' ' < CLAUDE.md | tr -s ' ' | grep -qF 'mutation that changes nothing is not'"
assert_ok "AGENTS.md carries it too" \
  bash -c "tr '\n' ' ' < AGENTS.md | tr -s ' ' | grep -qF 'Check the break was real'"
assert_ok "build says a new test is not trusted until it has failed once" \
  bash -c "tr '\n' ' ' < skills/build.md | tr -s ' ' | grep -qF 'not trusted until it has failed once'"
assert_ok "and says to suspect the mutation before the test" \
  bash -c "tr '\n' ' ' < skills/build.md | tr -s ' ' | grep -qF 'suspect the mutation before the test'"

section "layout checks its decision against every tool that reads it"
# layout's own first run: it proved `node --test` could not resolve the path
# alias and chose colocated tests on that basis - correctly - then did not check
# the typechecker, which rejects the extension the runner requires. `scaffold`
# hit a second failure the same decision had caused.
assert_ok "layout says one tool is half verified" \
  bash -c "tr '\n' ' ' < skills/layout.md | tr -s ' ' | grep -qF 'verified against one tool is half verified'"
assert_ok "and names which tools disagree" \
  bash -c "tr '\n' ' ' < skills/layout.md | tr -s ' ' | grep -qF 'the runner, the typechecker, the bundler'"

section "a half-built item can be handed to autopilot, and build says so"
# Found by a user asking why build stops after every step when `spec` had
# already done the thinking (2026-09-08). Two defects, and the second is the
# one that bites:
#
#   - `build`'s post-step menu offered Continue / Commit / Walk me through /
#     Stop, and never mentioned that unattended mode exists at all.
#   - `autopilot` would not accept `build` as a range start, and `spec..review`
#     cannot pick up a half-built item either, because `spec` correctly stops
#     when current-work.md holds an unfinished spec.
#
# Together: the choice to go unattended could only be made BEFORE building
# started, it was irreversible, and nothing said so. The option existed and was
# invisible at the exact moment someone wanted it.
# Range is the LIST ITSELF - to the first blank line, not to "Where it may end".
# The wider range swept up the explanatory paragraphs below, which also say
# `build`, so the assertion passed with `build` removed from the actual list.
# Fifth time a check here has had a range too broad to fail; caught by reverting.
assert_ok "autopilot accepts build as a range start" \
  bash -c "sed -n '/Where the range may start/,/^\$/p' skills/autopilot.md | grep -q '\`build\`'"
assert_ok "and says to resume from the first unchecked step" \
  bash -c "tr '\n' ' ' < skills/autopilot.md | tr -s ' ' | grep -qF 'Resume from the first unchecked step'"
assert_ok "and says why spec..review cannot do it instead" \
  bash -c "tr '\n' ' ' < skills/autopilot.md | tr -s ' ' | grep -qF 'cannot pick up a half-built item'"
assert_ok "build's post-step menu offers the unattended option" \
  bash -c "sed -n '/Then offer a short choice/,/^## /p' skills/build.md | grep -q 'autopilot build..review'"
assert_ok "and build says to offer it by name rather than on request" \
  grep -q 'Offer the unattended option by name' skills/build.md

section "no skill calls itself optional while another hard-stops without it"
# `architect` said "Skipping it is fine for a small enough project" for a day
# after the reorder made it mandatory: `stack` and `layout` both stop on a
# placeholder Architecture section. The documented small-project path was a
# false promise - skip it, and the very next skill refuses to run.
#
# The linter cannot see this: two files, both individually true, describing
# opposite contracts. Check it the only way that works - if a skill's output is
# somebody's hard precondition, that skill may not describe itself as skippable.
# Whitespace-collapsed before matching. The phrase wraps as "stop and say to
# run\n`architect` first", so a line-oriented grep finds nothing, the loop body
# never runs, and the section reports green having asserted nothing. That is the
# fourth time a check in this file has been defeated by its own line matching -
# it is why every one of them normalises first.
requires_count() {
  local target="$1" n=0 f
  for f in skills/*.md; do
    [ "$f" = "skills/$target.md" ] && continue
    tr '\n' ' ' < "$f" | tr -s ' ' | grep -qF "say to run \`$target\` first" && n=$((n+1))
  done
  echo "$n"
}
checked=0
for s_ in architect stack layout scaffold context; do
  requires=$(requires_count "$s_")
  if [ "${requires:-0}" -gt 0 ]; then
    checked=$((checked+1))
    assert_eq "$s_ is required, so it does not call itself skippable" "0" \
      "$(grep -ci 'skipping it is fine\|skipping this is fine\|is optional for a small' "skills/$s_.md" || true)"
  fi
done
# A loop that asserts nothing reports green. Prove it found something to check.
assert_ok "the rule actually found required skills to check" test "$checked" -ge 2
# And the replacement has to say what a short run looks like, or "required" just
# reads as more ceremony for a project that needs none.
assert_ok "architect says what a small project's run looks like" \
  grep -q 'short is the correct outcome' skills/architect.md
assert_ok "and that a six-no run is complete, not lazy" \
  grep -q 'That is a complete run' skills/architect.md

section "the six shape questions do not overstate what an answer settles"
# Found by running the loop on a real project (2026-09-08). Four files said
# "consistent across more than one write eliminates a single-file database".
# It does not: that is a transaction requirement and every relational database
# provides transactions, single-file ones included. What bears on the storage
# engine is concurrent writers - the *load* question.
#
# A rule stated too strongly is worse than a vague one. This one would have
# rejected SQLite for a project whose own quality bar licensed it, and the
# rejection would have read as rigour.
assert_eq "no file claims that answer eliminates a single-file database" "" \
  "$(grep -rln 'eliminates a single-file database\|rules out a single-file database' \
     --include='*.md' skills/ docs/ template/ 2>/dev/null || true)"
assert_ok "architect says a yes there settles no storage engine" \
  grep -q 'On its own it rules out no storage engine' skills/architect.md
assert_ok "and names concurrent writers as what does" \
  grep -q 'concurrent writers' skills/architect.md
assert_ok "stack reads the third and fifth answers together" \
  grep -q 'Read the third and fifth together, never the third alone' skills/stack.md

section "stack reads the quality bar rather than re-asking for it"
# The reorder updated stack's preconditions to treat the bar as an input and
# left Step 1 telling it to interview for the same information, ending with
# "`architect` turns these answers into the recorded bar" - which describes the
# order that no longer exists. One skill, two orders, both readable.
assert_eq "stack never says architect writes the bar afterwards" "0" \
  "$(grep -c 'turns these answers into the recorded bar' skills/stack.md || true)"
assert_ok "stack Step 1 says to read the bar, not ask" \
  grep -q 'do not ask this. Read it' skills/stack.md
# Matched against whitespace-collapsed text: the sentence is line-wrapped, and a
# naive grep reports absent for something that is present.
assert_ok "and says what to do when the file is missing" \
  bash -c "tr '\n' ' ' < skills/stack.md | tr -s ' ' | grep -q 'not a licence to interview'"

section "architect writes the system design inside the numbered section"
# Step 3 produces a block long enough to feel like a section of its own. Written
# as `## System design` it lands between plan sections 6 and 7 and silently
# changes where section 6 ends - and `context` addresses those sections by
# heading. Found by doing exactly that on a real project.
assert_ok "architect says sub-headings, not a new numbered section" \
  bash -c "tr '\n' ' ' < skills/architect.md | tr -s ' ' | grep -qF 'section 6, under'"
assert_ok "and says why - other skills address sections by number" \
  grep -q 'other skills address them by' skills/architect.md

section "ci proves the verify command from a clean checkout"
# `npm run verify` passed in the working tree and failed on a clean checkout:
# Next generates route types into a gitignored directory, so the runner had no
# LayoutProps and tsc reported a missing symbol - which reads as broken code,
# not a missing step. Any framework with generated types hits this.
assert_ok "ci says clean checkout, not just 'right now'" \
  grep -q 'from a clean checkout' skills/ci.md
assert_ok "and names generated files as the cause" \
  grep -q 'generated files are usually gitignored' skills/ci.md
assert_ok "and puts the fix in the verify command, not the workflow" \
  grep -q 'belongs in the verification command, not the pipeline' skills/ci.md
assert_ok "and Step 4 re-checks it after the command may have changed" \
  bash -c "sed -n '/^## Step 4/,/^## /p' skills/ci.md | grep -q 'clean checkout'"

section "something reconciles the data model against what the stack owns"
# A seam created by the reorder itself: the data model is now written before the
# stack, so a library chosen later can own tables the plan also specifies by
# hand. An auth library owning users is the common case, and `ideate` had
# already written a User table with columns. Two of them drift silently.
assert_ok "stack amends the data model when a library owns part of it" \
  grep -q 'section 4, the data model, wherever the chosen stack owns part of it' skills/stack.md
assert_ok "stack names auth as the usual case" \
  grep -q 'Auth is the usual one' skills/stack.md
assert_ok "stack says not to leave both descriptions standing" \
  grep -q 'Do not quietly leave both descriptions standing' skills/stack.md
assert_ok "context checks stack actually did it" \
  grep -q 'A data model the stack already owns' skills/context.md

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
ideate architect
architect stack
stack layout
layout scaffold
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

# The pair check above is satisfied by a mention anywhere in the file, and
# setup.md named `ci` in Step 5 - so `setup ci` passed while Step 7, the step that
# actually names the next action, said "running `context`" and never named `ci`.
# The file declared `setup -> ... -> ci -> context` at the top and told the
# reader the opposite at the end. A real adoption on 2026-09-11 followed Step 7;
# `progress` found three days later that neither had run. So the report step
# itself must name what the chain names, in the chain's order.
_chain=$(grep -E '^ +install -> setup ->' skills/setup.md | grep -oE '`[a-z-]+`' | tr -d '`' \
         | grep -vx spec | tr '\n' ' ' | sed 's/ *$//')
_step7=$(awk '/^## Step 7/{f=1; next} f && /^## /{exit} f' skills/setup.md | tr '\n' ' ' \
         | grep -oE '`[a-z-]+`' | tr -d '`' | awk '!seen[$0]++' \
         | while read -r n; do case " $_chain " in *" $n "*) echo "$n" ;; esac; done \
         | tr '\n' ' ' | sed 's/ *$//')
assert_eq "setup's chain still names what follows it" "ci context" "$_chain"
assert_eq "setup's report names the chain's next skills, in the chain's order" "$_chain" "$_step7"

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
# docs/ is in this list because leaving it out is how the miss happened:
# docs/anatomy.md - the file CLAUDE.md sends you to *before changing the
# workflow's shape* - said "check.sh has twelve rules" while every other file
# said 15, and its table stopped at rule 12.
assert_eq "the linter rule count in the docs is right" \
  "$(grep -oE '^# [0-9]+ ?[.-] ' check.sh | grep -oE '[0-9]+' | sort -n | tail -1)" \
  "$(grep -ohE '[0-9]+ rules' README.md AGENTS.md CLAUDE.md docs/*.md | grep -oE '[0-9]+' | sort -u)"
# ...and the count above can only be checked where it is written in digits. The
# stale one was spelled "twelve", which the assertion could not see at all.
assert_eq "no doc spells the rule count as a word" "" \
  "$(grep -rlniE '\b(six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|twenty) rules\b' \
       README.md AGENTS.md CLAUDE.md docs/*.md | tr '\n' ' ')"

section "no doc still calls a class unlintable that has a rule"
# The path that resolves to the wrong directory was the pack's standing example
# of something a linter could never catch - until declaring the product-level
# files made it rule 13. README and CLAUDE.md were updated; AGENTS.md still said
# "**The path one is not**" and docs/anatomy.md still said "Two classes are not
# lintable and never will be". Both are load-bearing: they tell the next person
# not to try, which is exactly the conclusion that was wrong for six recurrences.
unlintable=""
for f in README.md AGENTS.md CLAUDE.md docs/*.md; do
  tr '\n' ' ' < "$f" | tr -s ' ' \
    | grep -qE 'classes are not lintable|path one is \*{0,2}not\b' \
    && unlintable="$unlintable $f"
done
assert_eq "no doc claims the path class cannot be linted" "" "$unlintable"
assert_eq "every guide in docs/ is named in the entry points" "" \
  "$(for g in docs/*.md; do n=$(basename "$g"); grep -qF "$n" README.md AGENTS.md CLAUDE.md || echo " $n"; done)"

# status.md carries a tree listing with a count per directory, and three lines
# under it the instruction **Keep these counts current** - which is what was
# there while the listing said "26 files, one per skill" and the same file's own
# opening paragraph said 27 skills. An instruction to keep a number current is
# not a mechanism for keeping it current; this is.
assert_eq "status.md's skill count is right" \
  "$(ls skills/*.md | wc -l | tr -d ' ')" \
  "$(grep -oE '^skills/ +[0-9]+ files' dev-notes/status.md | grep -oE '[0-9]+')"
assert_eq "status.md's template file count is right" \
  "$(find template -type f | wc -l | tr -d ' ')" \
  "$(grep -oE '^template/ +[0-9]+ files' dev-notes/status.md | grep -oE '[0-9]+')"
assert_eq "status.md's guide count is right" \
  "$(ls docs/*.md | wc -l | tr -d ' ')" \
  "$(grep -oE '^docs/ +[0-9]+ guides' dev-notes/status.md | grep -oE '[0-9]+')"

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
# out of date is indistinguishable from a current one.
#
# This used to assert the list was empty, on the premise that every skill had
# run. `layout` broke that premise on 2026-09-08 by being split out of
# `architect` after the last real project was built. So the premise is now a
# declared list rather than a constant: name here every skill the section is
# allowed to call unrun, and the assertion fails the moment the prose and this
# list disagree - in either direction. **Run `layout` for real and this test
# fails until the caveat comes out**, which is exactly the alarm it existed for.
unproven=$(sed -n '/^## What is still unproven/,/^## /p' docs/anatomy.md \
  | awk '/^- /{if(b)print b; b=$0; next}
         /^[[:space:]]+[^[:space:]]/{b=b" "$0; next}
         {if(b)print b; b=""} END{if(b)print b}' | tr -s ' ')
# The skills the caveat may call unrun, and only these. Empty since 2026-09-08,
# when `layout` ran against a real Next.js project - and this line is what forced the prose to
# be updated in the same change rather than staying stale.
unrun_ok=""
assert_eq "only the declared skills are described as never run" "$unrun_ok" \
  "$(grep -i 'never been run\|never run' <<< "$unproven" | grep -oE '`[a-z-]+`' | tr -d '`' \
     | while read -r n; do [ -f "skills/$n.md" ] && echo "$n"; done | sort -u | tr '\n' ' ' | sed 's/ *$//')"
# Counted into a variable first. Interpolating $unproven into a `bash -c` string
# hangs: the text contains backticked skill names, which bash then treats as
# command substitution and waits on stdin for. Third time a test here has been
# broken by its own shell mechanics rather than by what it checks.
partly=$(grep -ci 'only part' <<< "$unproven") || partly=0
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

section "coverage.md is the only place the coverage numbers are written"
# The table exists because this exact question was reconstructed wrong three
# times inside status.md - "13 skills unrun" in one bullet, "23" in another, and
# "every skill has run" in the header. It fixed that file and nothing held the
# two documents that quote it: status.md sat a skill behind (26, written before
# `layout` existed) and anatomy.md listed `autopilot` among the partly-run when
# the table marks it yes, on a full unattended `spec..review` over a real
# two-part product. One declared source, two readers drifting from it, every
# file individually valid - the same shape as every other defect in this pack.
cov_total=$(grep -cE '^\| `[a-z-]+` \| (yes|partial|no) \|' dev-notes/coverage.md)
cov_partial=$(grep -cE '^\| `[a-z-]+` \| partial \|' dev-notes/coverage.md)
cov_names=$(grep -E '^\| `[a-z-]+` \| partial \|' dev-notes/coverage.md \
  | sed 's/^| `//; s/`.*//' | sort | tr '\n' ' ' | sed 's/ *$//')

# The NAMES, not the count. Counting rows passes a table that has the right
# number of them and the wrong ones in it - a row left behind by a rename reads
# as coverage for a skill that no longer exists, which is the same stale-entry
# failure check.sh already lints for in its own declared lists. Caught by
# mutating `layout` to `layout-x` and watching a row-count assertion pass.
assert_eq "coverage.md has a row for every skill and no others" \
  "$(ls skills/*.md | xargs -n1 basename | sed 's/\.md$//' | sort | tr '\n' ' ' | sed 's/ *$//')" \
  "$(grep -oE '^\| `[a-z-]+` \| (yes|partial|no) \|' dev-notes/coverage.md \
     | sed 's/^| `//; s/`.*//' | sort | tr '\n' ' ' | sed 's/ *$//')"

# status.md is a chronological log: its dated entries record what was true on
# the day they were written and must NOT be rewritten to today's numbers. Only
# the "Open / not done" section speaks in the present tense, so only it is held
# to the table. Scanning the whole file instead matched a 2026-09-07 entry and
# reported a stale claim that was in fact a correct record of the past.
_claim_text() {
  case "$1" in
    dev-notes/status.md) awk '/^## Open \/ not done/{f=1; next} f && /^## /{exit} f' "$1" ;;
    *) cat "$1" ;;
  esac | tr '\n' ' ' | tr -s ' '
}

# Both readers wrap the claim across lines, so the text is flattened to one line
# first - a line-based grep matches neither and reports them both absent.
_w2n() { case "$1" in one) echo 1;; two) echo 2;; three) echo 3;; four) echo 4;;
                      five) echo 5;; six) echo 6;; seven) echo 7;; *) echo "none";; esac; }
for _doc in dev-notes/status.md docs/anatomy.md; do
  _flat=$(_claim_text "$_doc")
  assert_eq "$_doc states the table's skill count" "$cov_total" \
    "$(grep -oE 'All [0-9]+ skills have now been run' <<< "$_flat" | grep -oE '[0-9]+' | head -1)"
  assert_eq "$_doc states the table's partial count" "$cov_partial" \
    "$(_w2n "$(grep -oE '(one|two|three|four|five|six|seven) (of them )?only partly' <<< "$_flat" \
              | grep -oE '^[a-z]+' | head -1)")"
done

# anatomy names them as well as counting them. A correct count naming the wrong
# skills is the version of this that reads as right.
_named=$(tr '\n' ' ' < docs/anatomy.md | tr -s ' ' \
  | grep -oE 'only partly[^.]*' | grep -oE '`[a-z-]+`' | tr -d '`' \
  | while read -r n; do [ -f "skills/$n.md" ] && echo "$n"; done | sort -u | tr '\n' ' ' | sed 's/ *$//')
assert_eq "anatomy names exactly the table's partly-run skills" "$cov_names" "$_named"

section "autopilot never requires what its own range produces"
# A precondition satisfied by a skill inside the range is circular: it blocks the
# run at a state the run itself would fix. autopilot had carved this out twice -
# the overview that `context` regenerates, the verification command that only
# exists once `scaffold` has run - and missed the third. `build` Step 2 creates
# the feature branch, and `ship` deletes it on merge, so the normal state between
# items is a clean `main`. The unconditional "on a branch, not `main`" gate made
# `autopilot spec..review`, the skill's own headline usage, unreachable from
# exactly the state the loop leaves you in.
# The carve-outs wrap across lines, so this matches against the file flattened to
# one line - a line-based grep silently missed two of the three and reported the
# skill broken when the pattern was.
flat=$(tr '\n' ' ' < skills/autopilot.md | tr -s ' ')
uncarved=""
for producer in context scaffold build; do
  case "$flat" in
    *"only when \`$producer\` is not in the range"*) ;;
    *) uncarved="$uncarved $producer" ;;
  esac
done
assert_eq "each circular precondition names the skill in range that satisfies it" "" "$uncarved"

assert_ok "the branch gate is conditional, not absolute" \
  grep -q 'on a branch, not `main` - \*\*only when `build` is not in the range' skills/autopilot.md
assert_ok "and says why refusing there breaks the documented usage" \
  grep -q 'makes the documented usage unreachable' skills/autopilot.md
# The half that must stay unconditional - an unattended run still cannot tell its
# own work from someone else's if the tree was dirty when it started.
assert_ok "while unrelated uncommitted changes still always stop it" \
  grep -q '^- no unrelated uncommitted changes' skills/autopilot.md

section "what the template ships, its writer knows to keep"
# template/README.md points a human at AGENTS.md - the only signpost a person
# gets, since the project README is a stub and AGENTS.md is named for agents.
# But `docs` owns the README and rewrites it, and its Step 2 listed everything
# the README must cover without mentioning that pointer. The first `docs` run
# would have removed it, and nothing would have reported that.
assert_ok "the template README points a human at AGENTS.md" \
  grep -q 'New here? Read `AGENTS.md` first' template/README.md
# Matched against the file flattened to one line - the instruction wraps, and a
# line-anchored pattern would be testing my line breaks rather than the meaning.
docs_flat=$(tr '\n' ' ' < skills/docs.md | tr -s ' ')
case "$docs_flat" in
  *"point a newcomer at \`AGENTS.md\`"*) _name="and docs, which rewrites that README, is told to keep it"; _ok ;;
  *) _name="and docs, which rewrites that README, is told to keep it"; _no "docs Step 2 never names AGENTS.md as the pointer to preserve" ;;
esac

# The general shape: docs is the README's writer, so anything the template puts
# there permanently needs docs to know about it.
assert_eq "docs is still the only skill that writes the project README" "1" \
  "$(grep -lE '^## Step [0-9]+ - the README' skills/*.md | wc -l | tr -d ' ')"

section "what AGENTS.md says is loaded is what CLAUDE.md loads"
# AGENTS.md opens with a table headed "These are already loaded, before you read
# anything else". CLAUDE.md is the file that does the loading, via @-imports.
# They disagreed: `fundamentals.md` and `needs-you.md` were promised and never
# imported. needs-you.md is touched by ten skills and is the whole basis on
# which `prepare`, `progress` and `preflight` decide whether a person is
# blocked - so the entry point told every cold session it had that context, and
# it did not. Every file was individually valid and all 13 rules passed.
#
# Checked in BOTH directions: a file imported but not listed is the same defect
# seen from the other end - context loaded that the entry point never explains.
awk '/These are already loaded/{f=1} /These are not loaded/{f=0} f' template/AGENTS.md \
  | grep -oE 'blueprint/context/[a-z-]+\.md' | sort -u > "$TEST_TMP/claimed.txt"
grep -oE 'blueprint/context/[a-z-]+\.md' template/CLAUDE.md | sort -u > "$TEST_TMP/imported.txt"

assert_eq "every file AGENTS.md calls auto-loaded is imported by CLAUDE.md" "" \
  "$(comm -23 "$TEST_TMP/claimed.txt" "$TEST_TMP/imported.txt" | tr '\n' ' ' | sed 's/ *$//')"
assert_eq "and CLAUDE.md imports nothing AGENTS.md does not list" "" \
  "$(comm -13 "$TEST_TMP/claimed.txt" "$TEST_TMP/imported.txt" | tr '\n' ' ' | sed 's/ *$//')"

# The table is only worth trusting if it is not empty - an awk range that stops
# matching would make both assertions above pass vacuously.
assert_ok "the claimed-loaded list is non-empty, so the check is not vacuous" \
  test -s "$TEST_TMP/claimed.txt"

section "every placeholder in AGENTS.md names the skill that fills it"
# AGENTS.md is the entry point every tool reads, and ships with sections left
# blank for the project to fill. Three of the four placeholders named the skill
# that fills them; `## What this is` said only "Replace this with..." - and no
# skill wrote it, so the entry point opened with an empty section in projects
# whose plans had been finished for weeks. The convention existed; writing it
# down is what makes it checkable.
#
# Both entry points are covered - the single-part template and the product root.
# A comment is allowed to name no skill ONLY if it is a structural marker that a
# script consumes, and that is verified rather than assumed: an exemption list
# nobody checks is how a dead marker survives.
unnamed=""
for tpl in template/AGENTS.md template/product/AGENTS.md; do
  while IFS= read -r block; do
    named=no
    for sk in skills/*.md; do
      n=$(basename "$sk" .md)
      case "$block" in *"\`$n\`"*) named=yes; break ;; esac
    done
    if [ "$named" = no ]; then
      # not a placeholder then - it must be a marker some script replaces
      # trailing separators are part of the character class, so strip back to
      # the last capital - "MULTI-PART MARKER -" is not a marker anyone greps for
      marker=$(grep -oE '[A-Z][A-Z -]{3,}' <<< "$block" | head -1 | sed 's/[^A-Z]*$//')
      if [ -n "$marker" ] && grep -rqF "$marker" lib/*.sh install.sh new-project.sh convert-to-parts.sh 2>/dev/null; then
        continue
      fi
      unnamed="$unnamed [$tpl: ${block:0:44}...]"
    fi
  done < <(awk '/<!--/{c=1; b=""} c{b=b" "$0} /-->/{if(c){print b; c=0}}' "$tpl")
done
assert_eq "no placeholder is left without a named filler" "" "$unnamed"

# Guard against the loop matching nothing and passing vacuously.
assert_ok "and there are placeholders to check" \
  test "$(cat template/AGENTS.md template/product/AGENTS.md | grep -c '<!--')" -ge 4

# The specific one this rule was written for. Matched on the instruction itself,
# flattened - "AGENTS.md" and "What this is" both occur elsewhere in context.md
# (a Product root read, and a bullet of project-overview.md), so looser patterns
# pass with the fix removed. A weak assertion here is the same defect one level up.
ctx_flat=$(tr '\n' ' ' < skills/context.md | tr -s ' ')
case "$ctx_flat" in
  *"Then fill \`AGENTS.md\`'s \`## What this is\`"*)
    _name="context declares itself the writer of 'What this is'"; _ok ;;
  *) _name="context declares itself the writer of 'What this is'"
     _no "context.md never says it fills AGENTS.md's What this is section" ;;
esac
case "$ctx_flat" in
  *"leave it alone if someone has already written prose"*)
    _name="and will not overwrite prose a person put there"; _ok ;;
  *) _name="and will not overwrite prose a person put there"
     _no "no rule protecting a hand-written description in a user-owned file" ;;
esac

section "context will not generate from sections that are still template"
# Its own preamble called Step 2 "the real gate", but Step 2 stops only on a
# CONTRADICTION - and an unfinished plan is a gap, not a contradiction. So
# placeholder Tech and Architecture were reported and then generated from
# anyway, producing exactly the "authoritative-looking file full of nothing"
# the step opens by warning about. Found by running it against plans written by
# someone else, which is the only way this shows up.
ctx=$(tr '\n' ' ' < skills/context.md | tr -s ' ')
_has() { case "$ctx" in *"$2"*) _name="$1"; _ok ;; *) _name="$1"; _no "not stated: $2" ;; esac; }

_has "Tech is a precondition filled by stack"          "**5. Tech** - filled by \`stack\`"
_has "Architecture is one filled by architect"         "**6. Architecture** - filled by \`architect\`"
_has "and it says why a gap needed its own gate"       "a gap is not a contradiction"

# The detection rule. Got right once by wording and nowhere written down - a
# length or non-empty test reads a section as filled when it holds the seeded
# sentence PLUS real content added underneath. That shape is the careful case:
# one real project's plan carries four genuine stack constraints below the seeded
# text in a section where no stack has been chosen.
_has "unfilled is defined by the seeded sentence surviving" \
  "the seeded instruction sentence is still present"
_has "and length is ruled out explicitly" "Do not use length or"

# One stop, not one per section - they are unfilled together in the normal case.
_has "every unfilled section is reported in one stop" "in a single stop"
_has "in loop order"                                  "in loop order"

# A stop still costs a round trip, so it should carry what Step 2 already sees.
_has "the stop still carries Step 2's findings" "alongside the stop"

# The rule detects "unfilled" by the seeded sentence surviving - so the template
# has to HAVE a recognisable seeded sentence in exactly the sections context
# gates on, and it has to name the skill that fills it. Reword the template and
# the gate silently stops detecting, with every file still valid on its own.
plan=template/blueprint/project-plan.md
for pair in "5:stack" "6:architect"; do
  num=${pair%%:*}; sk=${pair##*:}
  seeded=$(awk -v n="$num" '$0 ~ "^## "n"\\." {f=1; next} /^## [0-9]+\./{f=0} f' "$plan" \
           | grep -c "Filled in by the \`$sk\` skill")
  assert_eq "the plan template seeds section $num naming \`$sk\`" "1" "$seeded"
done

section "rescoping a live project cannot silently erase what was built"
# `ideate` assumed greenfield: Step 4 handed off to `stack` and `scaffold`, and
# nothing said what happens when the plan is already filled. Run on a project
# with four shipped items it would propose a fresh build plan - and approving one
# in good faith erases the `- [x]` marks that ARE the resume mechanism, then send
# a project that has code to `stack`, which refuses it. A dead end that destroys
# state on the way in.
id_flat=$(tr '\n' ' ' < skills/ideate.md | tr -s ' ')
_ideate() { case "$id_flat" in *"$2"*) _name="$1"; _ok ;; *) _name="$1"; _no "not stated: $2" ;; esac; }

_ideate "a filled plan stops instead of being overwritten" "stop and report what exists"
_ideate "and says why the checkboxes matter"               "entire resume mechanism"
_ideate "the destructive path needs an explicit argument"  "Never rewrite a filled plan without that argument"
_ideate "completed items keep their checkbox and history"  "Completed items keep their checkbox and their history"
_ideate "work in flight is not silently dropped"           "never silently dropped"
# The one that stops the plan and the code drifting apart.
_ideate "cutting a SHIPPED item routes to rollback"        "is \`rollback\`'s question"

# The hand-off was the dead end: a live project sent to a skill that refuses it.
_ideate "rescope hands off to setup and context" "Hand off to \`setup\` and \`context\`"
_ideate "and says explicitly not stack and scaffold" "not \`stack\` and \`scaffold\`"

# ideate was exempt from stating preconditions as a greenfield entry point. That
# claim died with the mode; check.sh fails if the heading and the exemption ever
# coexist, so this asserts the direction that matters.
assert_ok "ideate now states its preconditions" \
  grep -q '^## Before you start' skills/ideate.md
assert_fails "and is no longer on the exemption list" \
  grep -qE '^exempt_preconditions=.*[" ]ideate[" ]' check.sh

# A mode nothing documents is unreachable exactly like a skill nothing routes to -
# rule 7's problem wearing different clothes, and invisible to rule 7.
assert_ok "the walkthrough tells a reader the mode exists" \
  grep -q 'ideate --rescope' docs/walkthrough.md
assert_ok "and answers the stack question it sits next to" \
  grep -q 'Changing the stack after there is code' docs/walkthrough.md

section "the workflow graph holds together"
# Rule 7 requires every skill be routed to by another, which a closed cluster of
# skills citing only each other satisfies while being unreachable from the start.
# Reachability from an entry point is a different property and the one that
# matters: a skill nobody can arrive at is a skill nobody runs.
assert_eq "every skill is reachable from an entry point" "" "$(python3 - <<'GRAPH'
import pathlib, re, collections
skills = {p.stem for p in pathlib.Path('skills').glob('*.md')}
edges = collections.defaultdict(set)
for p in pathlib.Path('skills').glob('*.md'):
    body = re.sub(r'^description:.*$', '', p.read_text(), flags=re.M)
    for m in re.findall(r'`([a-z-]+)`', body):
        if m in skills and m != p.stem:
            edges[p.stem].add(m)
seen, queue = {'ideate', 'setup'}, ['ideate', 'setup']
while queue:
    for m in edges.get(queue.pop(), ()):
        if m not in seen:
            seen.add(m); queue.append(m)
print(" ".join(sorted(skills - seen)), end="")
GRAPH
)"

# Every skill orients the reader the same way. Two had no such line at all, which
# is a small thing until it is the file you opened first.
assert_eq "every skill says where it sits in the loop" "" \
  "$(for f in skills/*.md; do grep -q 'Where this sits' "$f" || printf ' %s' "$(basename "$f" .md)"; done)"

section "anatomy's copy of a declared list matches the declared list"
# anatomy.md names the precondition exemption by hand. Taking `ideate` off that
# list in check.sh left the doc naming a skill that is no longer exempt AND
# missing one that is - a stale copy of config, which is the same defect as a
# stale entry IN the config, one file further out. check.sh validates its own
# lists; nothing was validating the prose that repeats them.
declared=$(grep '^exempt_preconditions=' check.sh | sed 's/^[^"]*"//; s/"$//' | tr ' ' '\n' | sort | tr '\n' ' ')
documented=$(sed -n 's/.*rule 10: \(.*\) — the entry.*/\1/p' docs/anatomy.md \
             | grep -oE '`[a-z-]+`' | tr -d '`' | sort | tr '\n' ' ')
assert_eq "anatomy lists exactly the skills check.sh exempts" "$declared" "$documented"

# And the count in the same sentence, which is the half that reads as fact.
assert_eq "and its stated count is right" \
  "$(grep '^exempt_preconditions=' check.sh | sed 's/^[^"]*"//; s/"$//' | wc -w | tr -d ' ')" \
  "$(sed -n 's/.*\([A-Z][a-z]*\) skills are exempt.*/\1/p' docs/anatomy.md | head -1 | sed 's/Six/6/; s/Five/5/; s/Seven/7/; s/Four/4/; s/Eight/8/')"

section "a shipped feature's done-whens have a reader after ship"
# `verify` proved each item's done-whens once, at build time, and `ship` archived
# them under blueprint/history/. Seven skills touch that directory - none re-read
# the claims. So item 5 could break item 2's screen and nothing in the workflow
# would notice unless a test happened to cover it, while `verify`'s whole premise
# is that running the real app proves things tests do not. An archived record with
# no reader, which is this pack's signature defect one level up.
v=$(tr '\n' ' ' < skills/verify.md | tr -s ' ')
_v() { case "$v" in *"$2"*) _name="$1"; _ok ;; *) _name="$1"; _no "not stated: $2" ;; esac; }

_v "--all reads every archive, not the latest"  "the source is every archive"
_v "and says nothing has looked at them since"  "nothing in this workflow has looked at them since"
# A cut feature is not a regression - the link back to ideate --rescope.
_v "a feature cut by a rescope is not a regression" "no longer applicable"
_v "and names the rescope that cut it"             "ideate --rescope"
# A regression has no spec, so it cannot go back to build the way a failure does.
_v "regressions go to findings, not build"         "Raise it in \`blueprint/context/findings.md\`"
_v "and the run states its own cost"               "the most expensive check in this workflow"

# preflight is the gate that claims "whole project, not a diff" - it has to be
# the thing that requires this, or --all is a mode nobody runs.
pf=$(tr '\n' ' ' < skills/preflight.md | tr -s ' ')
case "$pf" in
  *"\`verify --all\`"*) _name="preflight requires the shipped features still work"; _ok ;;
  *) _name="preflight requires the shipped features still work"
     _no "preflight never names verify --all" ;;
esac
case "$pf" in
  *"never a pass"*) _name="and not-run counts as could-not-verify"; _ok ;;
  *) _name="and not-run counts as could-not-verify"; _no "no could-not-verify verdict for it" ;;
esac

section "something that renders has a way to be seen"
# `stack` chose a unit test runner and never asked how a web app gets LOOKED at.
# So `verify` had no way to observe a rendered page and every visual claim became
# could-not-verify - honest, and useless every time. The fallback was a person,
# and a person is not always there. Found on a real project: a Django app built
# and verified with nobody having seen a single page.
#
# The fix spans three skills, each doing its own job. This asserts the seam,
# because any one of them alone leaves the gap open.
st=$(tr '\n' ' ' < skills/stack.md | tr -s ' ')
vf=$(tr '\n' ' ' < skills/verify.md | tr -s ' ')
sc=$(tr '\n' ' ' < skills/scaffold.md | tr -s ' ')
_seam() { case "$3" in *"$2"*) _name="$1"; _ok ;; *) _name="$1"; _no "not stated: $2" ;; esac; }

_seam "stack settles a browser tool for what renders" "browser automation tool" "$st"
_seam "it is asked, not imposed"                       "ask whether they want a browser automation tool" "$st"
_seam "and recommends Playwright with its reasons"    "it is Playwright" "$st"
_seam "and takes no-harness as a real answer"         "no harness** as a real answer" "$st"
_seam "scaffold proves a browser actually launched"   "prove one browser launched" "$sc"
_seam "verify uses what the stack settled on"         "the browser automation tool the stack settled on" "$vf"
_seam "and still refuses to install one itself"       "Do not add one from this skill" "$vf"
_seam "and names where that decision belongs"         "name \`stack\` as where that gets decided" "$vf"
# The half that makes it more than tooling: a deferred human check is not a pass.
_seam "a deferred manual check never becomes a pass"  "Never let a deferred manual check quietly become a pass" "$vf"

section "ci does not promise more coverage than its triggers give"
# ci said "the only one that runs on every push" while prescribing triggers of
# pull requests plus pushes to the default branch. On a feature branch that is
# no runs at all - found on a real project, where an entire item was built and
# pushed with CI having seen none of it. A branch with no red marks is not a
# branch that passed.
ci=$(tr '\n' ' ' < skills/ci.md | tr -s ' ')
case "$ci" in
  *"is not \"on every push\""*) _name="ci says what its triggers do not cover"; _ok ;;
  *) _name="ci says what its triggers do not cover"; _no "the every-push claim is unqualified" ;;
esac
case "$ci" in
  *"a feature branch gets nothing until a pull request exists"*)
    _name="and names the case that surprises people"; _ok ;;
  *) _name="and names the case that surprises people"; _no "not stated" ;;
esac

section "ship's branch delete matches the merge it prescribes"
# ship squash-merges, then said "delete the branch after a clean merge". After a
# squash git does not record the branch as merged, so `git branch -d` refuses on
# work that is fully in main. Hit on a real project at the moment of shipping,
# which is the worst time to be guessing whether -D is safe.
sh=$(tr '\n' ' ' < skills/ship.md | tr -s ' ')
case "$sh" in
  *"squash-merge needs \`git branch -D\`"*) _name="ship names -D for a squash-merge"; _ok ;;
  *) _name="ship names -D for a squash-merge"; _no "not stated" ;;
esac
case "$sh" in
  *"do not reach for \`-D\` just because \`-d\` complained"*)
    _name="and guards against forcing a delete for the wrong reason"; _ok ;;
  *) _name="and guards against forcing a delete for the wrong reason"; _no "not stated" ;;
esac

section "making configuration required is a change to every environment"
# Removing a SECRET_KEY fallback was the correct repair and it broke CI, because
# the pipeline had been relying on the default without anyone noticing. The local
# run could not show it - the person making the change had the value exported.
# Found by shipping: green locally, red on the runner, two minutes later.
bd=$(tr '\n' ' ' < skills/build.md | tr -s ' ')
_b() { case "$bd" in *"$2"*) _name="$1"; _ok ;; *) _name="$1"; _no "not stated: $2" ;; esac; }

_b "build names the required-config shape"        "makes configuration *required*"
_b "and that the local run is where it hides"     "the one place it will not show"
_b "and sends it to the Environments table"       "Environments table in \`AGENTS.md\`"
_b "and treats the pipeline as an environment"    "A pipeline is an environment"
_b "and requires saying so in the handoff"        "This now requires"
# Naming a variable and assigning the work of producing one are different things.
# A Django project named DJANGO_SECRET_KEY in .env.example, the plan and AGENTS.md - and in
# none of them was it a thing a person had to DO. needs-you.md is that list.
_b "a value only a person can supply goes to needs-you" "If a person has to supply the value"
_b "and says naming is not assigning"                   "Naming a variable is not the same as assigning"

section "how many env files, and when splitting earns it"
# Asked directly: should config be split per service? The honest answer has a
# condition attached, and without it "one file per service" reads as tidiness.
ho=$(tr '\n' ' ' < skills/host.md | tr -s ' ')
case "$ho" in
  *"One per environment is the default"*) _name="one file per environment is the default"; _ok ;;
  *) _name="one file per environment is the default"; _no "not stated" ;;
esac
case "$ho" in
  *"Split when the boundary exists"*) _name="splitting needs a boundary, named"; _ok ;;
  *) _name="splitting needs a boundary, named"; _no "not stated" ;;
esac
case "$ho" in
  *"a new way to have exactly one of them missing"*)
    _name="and the cost of splitting is stated"; _ok ;;
  *) _name="and the cost of splitting is stated"; _no "not stated" ;;
esac

section "the overview is refreshed by whatever makes it stale"
# `ship` ticks an item off build-plan.md and resets the spec on EVERY item, so
# the overview's Current state is wrong the moment it finishes - wrong item
# count, wrong next item. Its handoff named integrate, preflight, deploy and
# spec, never context; and context's re-run list named `spec` as an editor and
# not `ship`. Both halves missing, so the file every cold session loads went
# stale once per item. Caught by autopilot's precondition on a real project -
# a check most people never reach.
sp=$(tr '\n' ' ' < skills/ship.md | tr -s ' ')
cx=$(tr '\n' ' ' < skills/context.md | tr -s ' ')
_pair() { case "$3" in *"$2"*) _name="$1"; _ok ;; *) _name="$1"; _no "not stated: $2" ;; esac; }

_pair "ship routes to context after a merge"      "after every ship" "$sp"
_pair "and says why a stale overview matters"     "starts the next session on a false picture" "$sp"
_pair "context lists ship as a reason to re-run"  "After every \`ship\`" "$cx"
_pair "and names it the most frequent one"        "most frequent reason to re-run" "$cx"

section "the lessons a real deployment taught"
# Every one of these came from taking one project from ideate to a live, backed
# up, TLS-terminated deployment. None was visible from inside the pack.
sc=$(tr '\n' ' ' < skills/scaffold.md | tr -s ' ')
st=$(tr '\n' ' ' < skills/stack.md | tr -s ' ')
ho=$(tr '\n' ' ' < skills/host.md | tr -s ' ')
_l() { case "$3" in *"$2"*) _name="$1"; _ok ;; *) _name="$1"; _no "not stated: $2" ;; esac; }

# Three wirings failed the same way in one project; the third was a P0 that put
# the database inside the release directory. A formatter then hid all three.
_l "scaffold warns against anchoring on a quoted string" "never on a quoted string" "$sc"
_l "and that a formatter erases the evidence"            "erase the evidence" "$sc"
_l "and says to verify by asking the program"            "asking the program, not by reading the file" "$sc"

# import venv passes on a box where venv cannot create anything.
_l "importing a module is not the module working" "is not \`venv\` working" "$sc"

# The version check was run against the build machine, not the target.
_l "stack checks the runtime of the machine it will run on" "not only this one" "$st"

# cp on a live SQLite file yields something that opens and is wrong.
_l "host says copying a live database file is not a backup" "is not a backup of a database that is running" "$ho"
_l "and that restoring means starting the app on it"        "starting the application against the copy" "$ho"
_l "and that a box ships less than a laptop"                "What is actually installed on it?" "$ho"

section "a finished plan is not the end of the project"
# A real project shipped all 8 items, and the question "how do I add a delete feature"
# had no answer. `spec` could add a plan item only from a `monitor` observation,
# so a plain feature request fell into ad-hoc fix mode - which says "not a plan
# item", so the work lands and the plan quietly stops describing the product.
# And section 11, the deferred list, had a writer and no reader at all.
sp=$(tr '\n' ' ' < skills/spec.md | tr -s ' ')
pr=$(tr '\n' ' ' < skills/progress.md | tr -s ' ')
_f() { case "$3" in *"$2"*) _name="$1"; _ok ;; *) _name="$1"; _no "not stated: $2" ;; esac; }

_f "spec takes a new feature as a plan addition" "a new feature described in prose" "$sp"
_f "and distinguishes it from an ad-hoc fix"     "A new feature is a plan addition, not an ad-hoc fix" "$sp"
_f "and reads the deferred list before adding"   "Check the deferred list first" "$sp"
_f "and says a finished plan is normal here"     "A finished plan is the normal case" "$sp"

# The deferred table needs a reader, or a decision to postpone becomes a deletion.
_f "progress surfaces what was deferred"         "what \`ideate\` deferred and when" "$pr"
_f "and the open findings as half-written specs" "specs half-written" "$pr"
_f "and says why an unread deferral rots"        "quietly became a deletion" "$pr"

section "deploy will not quietly ship an unmerged branch"
# A real deployment went live from a feature branch: `main` had neither the P0
# database repair, nor the error pages, nor the login lockout. Every gate in
# deploy's readiness list passed - it asks that the commit be identified, and
# never that it be merged. CI then tested something other than what was running.
dp=$(tr '\n' ' ' < skills/deploy.md | tr -s ' ')
_d() { case "$dp" in *"$2"*) _name="$1"; _ok ;; *) _name="$1"; _no "not stated: $2" ;; esac; }

_d "deploy checks the commit is on the default branch" "that commit is on the default branch"
_d "and names CI drifting from production"             "CI is testing something other than what is live"
_d "and that the next deploy silently reverts"         "next deploy silently reverts production"
# A hotfix ahead of the merge is legitimate; the rule is a stop, not a refusal.
_d "it stops and asks rather than refusing"            "Not a refusal - a stop and a question"
_d "and requires recording the exception"              "then record it"

finish
