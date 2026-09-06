---
name: ship
description: "Close out finished work: run a final safety pass, archive the spec under `blueprint/history`, check the item off in `blueprint/build-plan.md`, reset `blueprint/context/current-work.md`, make one work-level commit, then squash-merge the branch with explicit approval. Refuses to merge while a P0 or P1 finding is open or fixed in blueprint/context/findings.md. Asks separately before pushing. Use when the user runs `ship`, or asks to finish, wrap up, merge, or close out the current item once it is built and reviewed."
---

# ship - log it, commit it, merge it

Where this sits:

    `build` -> `verify` -> `review` -> ship -> next item

`build` built the work on a branch, with optional per-step checkpoints.
This closes it: logs it, makes the single work-level commit, and squash-merges so
the item lands on `main` as one clean commit regardless of how many checkpoints
the branch carried.

Run it only when the work is done, verified, and reviewed.

## Before you start

**If `blueprint/context/current-work.md` holds no completed spec, stop.** There is
nothing to close out, and resetting it destroys whatever is in flight.

Name which of these has not happened rather than merging past it - Step 1 turns
the ones that matter into a hard stop:

- **`verify` has not run** - the code compiles and nobody has watched it do the
  thing the spec promised.
- **`review` has not run** on this work - the merge gate reads the findings
  ledger, and an empty ledger because nothing looked is indistinguishable from an
  empty ledger because nothing was wrong.

## Step 1 - the safety pass

Before logging or committing anything, check each of these and **report only the
blockers**:

- `blueprint/context/current-work.md` holds a real spec, and every build step is ticked.
- The work is on a branch, not on `main` or `master`.
- The changed files belong to this spec, with no unrelated work mixed in. A dirty
  `blueprint/context/findings.md` is expected - `review` writes it.
- The project's verification command passed **in this session**. If none is
  declared, the build passed, and the tests passed when the project has a test
  command and this change touched logic.
- Behavioral done-whens have `verify` evidence. Do not merge on an
  unverified claim.
- **No P0 or P1 finding in `blueprint/context/findings.md` is `open` or `fixed`.**

That last one is the gate. `fixed` still blocks on purpose: the repair exists but
no review has looked at it - run `review` to close it out. The only ways
past without more code are `accepted` (the user's explicit decision in this
conversation, with their reason recorded) or `invalid` (a `review`
verdict backed by evidence). **Never set either on the user's behalf.** A missing
ledger file means no findings.

**Evidence, or it didn't happen.** Never report "passes", "works", or "verified"
without naming what proves it - the command and its output, the screenshot, the
response body. "I couldn't verify this" and "this failed" are useful, honest
results. A fabricated pass is worse than no check at all, because it retires the
question.

If required evidence is missing, **stop here.** Do not proceed to Step 2 and
mention it afterwards.

## Step 2 - log the work

Check what kind of item this is - the spec's `Type:` line - and archive
accordingly:

- **Feature** - archive `blueprint/context/current-work.md` to
  `blueprint/history/features/NN-name.md`, where NN is its build-plan number, and
  check it off in blueprint/build-plan.md. Check the parent item too, but only once
  every sub-item under it is checked.
- **Fix** - archive to `blueprint/history/fixes/name.md`. A fix is not a plan
  item, so nothing gets checked off.
- **Rollback** - archive to
  `blueprint/history/rollbacks/YYYY-MM-DD-NN-name.md`, **preserving the original
  feature's archive**. Uncheck the target item in `blueprint/build-plan.md` and append
  a short note to its line with the date and the rollback's archive path. Keep
  the item's number stable.

**Archive the resolved findings with it.** Append a `## Findings` section to the
archive file holding every `closed`, `accepted`, or `invalid` entry at its final
status, with `accepted` entries keeping their recorded reason. Prefix each ID
with the archive name so it stays unique forever: item 12's `F-03` becomes
`12/F-03`. Then remove those entries from the ledger.

Unresolved entries - `open` or `fixed` at P2 or P3, and `unverified` leads - stay
in the ledger with their IDs. They are never silently dropped. When nothing is
left, reset `blueprint/context/findings.md` to its stub:

    # Findings

    _No findings recorded. `review` appends findings here when it finds them._

Then reset `blueprint/context/current-work.md` to its stub:

    # Current work

    > **Working file.** The one item in flight - a feature, a fix, or a rollback.
    > The `spec` skill writes it, `build` ticks its steps off as they land, and
    > `ship` archives it under blueprint/history and resets this file.

    _Nothing in progress. Run the `spec` skill to start the next item, or
    describe a bug to spec it as a fix._

**Both stubs are quoted here because by the time this skill runs they have been
overwritten** - "reset it to its stub" is an instruction with no source to
restore from, and the result is every project inventing slightly different
wording for the same state. `spec` and `progress` both read this file to decide
whether anything is in flight; two spellings of "nothing" is how that check
starts missing.

**Discard consumed prototypes, and confirm it worked.** If this item built the look from
prototypes - its design reference pointed there and an early step ported
the theme into the app - delete that directory now and fold the deletion into
this commit. The tokens live in the app's own theme now - a stylesheet, a theme object, or
`ThemeData`, depending on the platform - and the mockups were always throwaway. Skip this if the item did not consume them.

**Keep `blueprint/context/design.md`.** The mockups go; the decisions in them
stay. Deleting the record along with the mockups is how the next UI item ends up
reinventing the loading state.

**Then check the directory is actually gone before continuing.** In a real
project built with an earlier version of this workflow, `prototypes/` survived
thirteen consecutive features because this step was an instruction with nothing
verifying it. An instruction with no check is a suggestion. If it is still there,
say so and stop rather than reporting a clean finish.

Do not commit yet. The next step makes one commit covering the code and this
bookkeeping together.

## Step 3 - the work commit

Stage everything on the branch - any uncommitted step work plus the Step 2
logging - and make **one** conventional commit: `feat: <name>`, `fix: <name>`,
`revert: roll back <name>`.

The project's verification command must pass first.

## Step 4 - merge, then stop

1. **Squash-merge the branch into `main`, only with the user's explicit
   go-ahead.** The item lands as one commit.
2. Delete the branch after a clean merge.
3. **Stop and ask** whether to push `main` to its upstream. Approval to merge is
   not approval to push, and neither is running this skill.
4. Push only after a separate, explicit yes **in this conversation**. If the repo
   has no remote, say so rather than guessing.

Then finish with a short **how to try it** note for the completed work - or, for
a rollback, how to confirm the removed behavior is gone plus one unaffected path
worth re-checking. If that would run past a couple of steps, point at
`verify` instead.

**In a multi-part project, clear this part's packet** in `<product root>/blueprint/status/<this part>.md`,
resetting the whole file rather than only the state:

    **State:** idle
    **Item:** -
    **Blocked on:** -
    **Review packet:** -
    **Updated:** <today>

The path is relative to `AGENTS.md`'s `Product root:`. Shipping is what closes a review, and a queue nothing empties
eventually blocks every unattended run in the product.

**Clearing `Item:` and `Blocked on:` matters as much as clearing the packet.** A
shipped part still naming the item it finished reads as work in flight, and a
block left behind after the thing it waited for shipped is the exact "stale
block" `orchestrate` has to go hunting for - and which stops another part from
starting for no reason at all.

Then point at what is next:

- **`ci`** only if it was never set up, or if this item changed what the checks
  are. It normally runs right after `scaffold`, long before here. A green suite that only
  runs when someone remembers is a suite that will eventually stop being run.
- **`docs`** if this item made a decision worth recording, or if the README still
  does not describe what the project actually does now.
- **`integrate`** if this project has more than one part. This part passing its
  own checks says nothing about whether it still agrees with the others - and
  agreeing is what breaks when parts are built in parallel.
- **`preflight`** before a first release, and before a milestone one. Merging
  proves this item is sound; it says nothing about whether the project can face
  users at all - backups, configuration, operations, a README that describes what
  this actually is. **`deploy` gates production on `preflight` having returned
  go**, so a loop that never names it here arrives at that gate with nothing
  behind it. It is allowed to answer no-go, and that is it working.
- **`deploy`** if this project is already live. Merging put the work on `main`;
  it did not put it in front of anyone. **This is the step most easily forgotten**,
  because the loop feels finished at the merge and the branch is gone.
- otherwise **`spec`** for the next item.

## Rules

- **The item is the unit of history.** One squashed commit on `main` per feature,
  fix, or rollback, however many checkpoints the branch carried.
- **Never merge failing or unfinished work.**
- **Never merge past the findings gate.** The recorded ways through are
  `accepted` and `invalid`; both travel into the archive, never a silent drop.
- **A rollback preserves the original archive** and adds its own. Never rewrite
  history to make a feature look as though it never existed.
- **Merging and pushing are separate decisions, and both are the user's.**
- **One item per run.** A parent with unchecked sub-items stays unchecked.

## Formatting

Match the conventions in `blueprint/context/ai-interaction.md` when it exists: short, scannable
markdown, lists for enumerations, a table when comparing options. Otherwise keep
it brief and direct by the same standard. Long prose blocks are the failure mode
to avoid - this output gets read while someone is mid-task.
