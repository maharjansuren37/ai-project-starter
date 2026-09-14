# AGENTS.md

Instructions for AI coding agents working on **the pack itself** - not a project
built with it. There is no `blueprint/` here; this repo *ships* that. Claude Code
reads `CLAUDE.md`, which says the same things.

**Start with `dev-notes/status.md`** - it opens with checking what is uncommitted
and what to run to confirm the tree is intact, and neither is guessable. Then
**`README.md`** for what this is and how it installs, then
**`docs/anatomy.md` before changing the workflow's shape** — what every part
reads, writes and gates on, in one place. `dev-notes/decisions.md` records why
the repo is shaped this way; read D2 and D3 before restructuring it.

The other three guides in `docs/` are `walkthrough.md` (one project start to
shipped), `mobile.md` and `multi-part.md`.

## Working on this

```bash
./check.sh
```

Validates frontmatter, that each skill's name matches its filename, step numbers
in order, no tool-specific `/skill` references, no references to retired names,
**that no skill is unreachable** — every skill must be routed to by another —
**that every script is referenced** by some doc, skill or other script,
**that every field on the coordination board has a writer**, **that every state
file has a declared writer that really writes it**, **that every skill states
its preconditions**, **that every file living at the product root is named
as one** by each skill that reads it, **that every skill writing a foundational
decision says what happens when that decision already exists**, and **that every
mode a skill declares is named in its description** — the description is what an
agent matches on, so a mode missing from it cannot be reached — 15 rules.

```bash
./tests/run.sh          # everything
./tests/run.sh lint     # one file: lint | scripts | seams
```

`tests/test-lint.sh` breaks one linter rule at a time in a throwaway copy and
asserts `check.sh` fails **and names the right problem**; `tests/test-scripts.sh`
runs the scripts and inspects what they produced; `tests/test-seams.sh` checks
the cross-file invariants nothing else can see.

**The runner fails three assertions on purpose first**, to prove the harness can
report a failure at all. A rule here once shipped unable to fail, printing its
error from a subshell and returning 0 — a suite with that flaw reports everything
clean and hides whatever is underneath. **Before changing the workflow's shape**, read *Changing the workflow's shape*
in `docs/anatomy.md`. Five kinds of change have broken this pack repeatedly -
adding a state file, adding a handoff, reordering the loop, adding a skill,
splitting into parts - and each has one step that is easy to skip and invisible
afterwards. The step is
always a **declaration**: these rules can only check what has been written down,
which is why every one of them reads a list in `template/AGENTS.md`.

**Add a test with the fix, not after it** - then break the fix and watch the test
fail. **Check the break was real:** a mutation that changes nothing leaves a test
passing against "broken" code, and it reads exactly like a proven one. Mutate what
the assertion names.

**The cross-file rules exist because the file-level ones could not see the worst
bugs found here**: a script nothing routed to, a board field with four readers
and nothing that ever set it, a state file whose only writer was on the wrong
route, and a path that resolves to a part's own directory when the file lives at
the product root. Every one of them passed every file-level check.

Each is driven by a **declared list** rather than by a smarter check - in
`template/AGENTS.md` for the rules about a product's files, and in `check.sh`
itself for the rules about skills (`entry_points`, `exempt_preconditions`,
`decision_skills`). That is the move to copy when a new class shows up: write
down what was implicit, and the rule follows.

**The list is the rule.** Adding a skill to `decision_skills` is what forces the
question rule 14 exists to ask, so a new decision-writing skill has to be put
there deliberately - and a stale name in any of those lists is itself an error,
because dead config hides the thing it was meant to check.

Skills live in `skills/`, one file each. `install.sh` fans them out to both
adapter directories and generates an `.opencode/command/` wrapper per skill, so
there is only ever one copy to edit.

## The thing that keeps biting

**Five times now**, a mechanism spanning several files has been broken while
every one of them passed the linter: a reader with no writer (twice), a path
resolving to the wrong directory (twice), and a script nothing routed to.

Three of those classes are lintable and now are — rules 8, 9 and **13**. The
path one resisted longest: it recurred six times, and the audit that fixed
`<product root>/` paths in four skills missed `orchestrate` because it went
looking for *writers* and `orchestrate` is the reader.

**It became lintable once the product-level files were declared** — rule 13
reads that list from `template/AGENTS.md` and requires every skill naming one to
say where it resolves. Writing the rule immediately found five more skills
reading a product plan that does not exist inside a part, `host` among them,
which reads it to decide whether to spend money. **The move that worked was not
a cleverer check; it was writing down what had been implicit.**

So when a mechanism crosses more than one file, ask directly: *who writes this,
and where does it actually land?* And check the answer by running it — every one
of these was found by comparing what a command produced against what was claimed,
never by reading.
