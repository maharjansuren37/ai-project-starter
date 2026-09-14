# Orchestration

> **The coordination board.** Every session reads this before starting and writes
> its own status file when its state changes. There is no message passing between
> agents — files are how they coordinate, and they are committed because they are
> state.
>
> Maintained by the `orchestrate` skill. Present only in a multi-part project.

**Mode:** orchestrated
**Contract:** _none yet_ — **NOT FROZEN**

The contract line above is the one genuinely shared decision, and **only
`orchestrate` writes it.**

## Where each part's state lives

**One file per part**, under `blueprint/status/`:

    (none yet - `lib/seed-part.sh` lists each part here as it seeds it)

**Each part writes only its own file, and no file has two writers.** That is what
makes this safe when sessions genuinely run at the same time — as they do when a
subagent is driving each part. A single shared table with a row per part would
need every writer to rewrite the whole file, and two finishing at the same
instant would silently lose a row. Measured, it is worse than that: three
concurrent writers doing 300 updates each left the shared file **empty** - not
short a row, but truncated to nothing, while three separate files came through
the identical load intact. **Separate files remove the race by
construction rather than by convention.**

Each status file:

    # web

    **State:** building
    **Item:** 2. Login screen
    **Blocked on:** -
    **Review packet:** -
    **Updated:** 2026-09-01

**States:** `idle` · `spec'ing` · `building` · `waiting` (for review) ·
`blocked` · `stopped` (an unattended run stopped early — say why)

### Who writes what

Every field has a named writer. **A field with a reader and no writer is worse
than a missing field** — it reads as a confident `-` forever, and the skill
consuming it reports all-clear on data nobody ever supplied.

| Field | Written by | Cleared by |
|---|---|---|
| `State` | `spec` → `spec'ing`, `autopilot` → `building`, `build` → `waiting`, any of the three → `blocked` / `stopped` | `ship` → `idle` |
| `Item` | `spec` on claiming, `autopilot` and `build` on the item they are working | `ship` |
| `Blocked on` | `spec`, `build`, `autopilot` — whichever stops for something another part owns | `ship`, or the part's own next session once the dependency lands |
| `Review packet` | `build` | `ship` |
| `Updated` | every write above | — |

`orchestrate` **reads all of these and writes none of them.** It reports a stale
block; the blocked part clears it. That keeps the one-writer-per-file guarantee
intact, which is the whole reason these are separate files.

## The review queue

A part with a **Review packet** line that is not `-` has work waiting to be read.

> **The cap:** `autopilot` refuses to start a new unattended run while **two**
> parts already have a packet waiting. Unattended work must not outrun your
> ability to read it — that is the point of the number, not a technicality.

## Rules

- **A part writes only its own status file.** Never another part's, and never the
  contract line.
- **Read before starting.** If the contract is not frozen, or this part is
  blocked, stop and say so rather than building work that gets thrown away.
- **Record stopping, not just finishing.** A file still reading `building` after
  a run has stopped is worse than none at all, because it looks like progress.
- **Write the block, do not just say it.** A part waiting on another part records
  it in `Blocked on:`. Said in the conversation and nowhere else, it is invisible
  to `orchestrate` — which finds deadlock, unowned blocks and stale blocks by
  reading that field and nothing else.
- **Every session updates its file, not only unattended ones.** A board that
  reflects `autopilot` runs alone reports a part idle while a person is building
  in it — a coordination file that misleads the coordinator.
