# AGENTS.md

Instructions for AI coding agents working on **the pack itself** - not a project
built with it. There is no `blueprint/` here; this repo *ships* that. Claude Code
reads `CLAUDE.md`, which says the same things.

**Start with `README.md`** for what this is and how it installs, then
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
its preconditions**, and **that every file living at the product root is named
as one** by each skill that reads it — 13 rules.

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
in `docs/anatomy.md`. Four kinds of change have broken this pack repeatedly -
adding a state file, adding a handoff, adding a skill, splitting into parts - and
each has one step that is easy to skip and invisible afterwards. The step is
always a **declaration**: these rules can only check what has been written down,
which is why every one of them reads a list in `template/AGENTS.md`.

**Add a test with the fix, not after it.**

**The cross-file rules exist because the file-level ones could not see the worst
bugs found here**: a script nothing routed to, a board field with four readers
and nothing that ever set it, a state file whose only writer was on the wrong
route, and a path that resolves to a part's own directory when the file lives at
the product root. Every one of them passed every file-level check.

Each is driven by a **declared list** in `template/AGENTS.md` rather than by a
smarter check. That is the move to copy when a new class shows up: write down
what was implicit, and the rule follows.

Skills live in `skills/`, one file each. `install.sh` fans them out to both
adapter directories, so there is only ever one copy to edit.

## The thing that keeps biting

**Five times now**, a mechanism spanning several files has been broken while
every one of them passed the linter: a reader with no writer (twice), a path
resolving to the wrong directory (twice), and a script nothing routed to.

Two of those classes are lintable and now are — rules 8 and 9. **The path one is
not**, and it has recurred: the audit that fixed `<product root>/` paths in four
skills missed `orchestrate`, because it went looking for *writers* and
`orchestrate` is the reader.

So when a mechanism crosses more than one file, ask directly: *who writes this,
and where does it actually land?* And check the answer by running it — every one
of these was found by comparing what a command produced against what was claimed,
never by reading.
