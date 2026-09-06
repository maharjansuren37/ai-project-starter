# AGENTS.md - the product root

Instructions for AI coding agents working at the **product root** of a multi-part
project, and the entry point every tool reads. Claude Code reads `CLAUDE.md`,
which imports this file, so there is one source of truth.

**This directory is not a part.** No code is built here and there is no build
loop: no `build-plan.md`, no `current-work.md`, no findings ledger. What lives
here is the product plan, the coordination board, and the contract between the
parts.

## The parts

<!-- PARTS -->

Each part is a full project of its own - its own `AGENTS.md`, its own
`blueprint/`, its own loop. **Open the part's directory to work in it**, not this
one.

## What is here

- `blueprint/project-plan.md` - the product: problem, users, features, the parts
- `blueprint/orchestration.md` - the coordination board: the contract line and
  the rules
- `blueprint/status/<part>.md` - one live-state file per part, each written only
  by that part's own sessions
- `contracts/` - the boundary between the parts, owned by the part that can
  break it
- `dev-notes/` - decisions and status for the product as a whole

## The contract

<!-- `architect` fills this in, and `scaffold` creates the file. Until then the
     parts have no agreed boundary and none of the cross-part checks can run. -->

- Owner: <which part defines it - usually the backend>
- File: <e.g. `contracts/openapi.yaml`>
- Kind: <generated | hand-written>
- Regenerate: <command, and the directory it runs from>
- Generate clients: <command per consuming part, and where each runs>

**These are read, not decorative.** `ci` runs the regenerate command on every
push and fails if the result differs from what is committed; `integrate` does the
same before a deploy. Both need the real command, and "the contract file" in the
abstract is not one. A hand-written contract has no regenerate command - say so
here, because it makes those checks weaker and the report should admit it.

## Paths mean something different here

**At this root, `blueprint/` is the product's.** Inside a part, `blueprint/` is
*that part's*, and the product's is at the path in that part's `AGENTS.md`
`Product root:` field.

Every skill that reaches across the boundary - `orchestrate` above all - resolves
its paths against the product root. Getting this wrong is quiet rather than loud:
the file is simply written somewhere nobody reads, and every individual file
still looks correct.

## Run these here

- **`orchestrate`** - the board. What each part is doing, what is blocked and on
  what, whether the contract is frozen, how deep the review queue is, and the one
  thing to do next. **This is the status skill for the product**; `progress`
  answers the same question inside a single part.
- **`ideate`, `stack`, `architect`** - the planning that must happen once, for the
  whole product, before any part starts.
- **`integrate`** - proves the parts actually agree. Every part passing its own
  checks is not evidence of that.
- **`preflight`** - whether the product as a whole can face real users.

## The sequence that matters more than the tooling

1. **Together, single-threaded.** `ideate`, `stack`, `architect`, and the contract.
   Parallelising this is how several agents invent several incompatible
   assumptions that only surface at integration.
2. **Freeze the contract.** `orchestrate` will not move parts into parallel work
   until it is frozen.
3. **Parallel.** Each part runs `spec -> build -> verify -> review -> ship` in its
   own directory, one session each.
4. **`integrate`**, then `deploy`.
5. **A contract change stops everything.** It should feel expensive.

## Rules that hold regardless of skill

- **Never build on `main`.** Work happens on a branch.
- **Never commit code the user has not seen and approved.**
- **Never push, deploy, provision, or change a remote service** without a
  separate explicit yes in the current conversation.
- **Never claim something passes without naming the evidence** - the command and
  its output, the screenshot, the response.
- **Never print or commit a secret.** Report the category, file, and line.
- **Never write another part's status file.** One writer per file is what makes
  parallel sessions safe; it is a guarantee, not a convention.
- **Only `orchestrate` writes the contract line.**
