---
name: build
description: "Build the spec in `blueprint/context/current-work.md` one small reviewed step at a time. Creates the matching branch, implements a single step, shows the diff and explains it in plain English, runs the project's checks, and iterates until it works - then ticks the step off so progress survives a context clear. Offers an optional commit checkpoint after each approved step; the work-level commit and the merge belong to `ship`. Resumes from the first unchecked step when a session was interrupted. Use when the user runs `build`, or asks to build, implement, code, or start the current spec."
---

# build - turn the spec into code, one reviewed step at a time

Where this sits:

    `spec` -> build -> `verify` -> `review` -> `ship`

The spec is written and reviewed. This turns it into code without vibe coding:
one small step at a time, each with a visible diff, a plain-English explanation,
and a check that it works - all behind the user's approval.

## Before you start

Read blueprint/context/current-work.md. If it holds no real spec - still the stub, or already
marked complete - stop and say to run `spec` first. Building without a
spec is the thing this workflow exists to prevent.

**The standards are two files:** `blueprint/context/fundamentals.md` holds what
is true regardless of stack and is the pack's - refreshed on every install.
`blueprint/context/coding-standards.md` is this project's and is never
overwritten. **Read both; where they disagree, the project's own file wins.**

**If `coding-standards.md` is still unfilled prompts, say so.** The fundamentals
always apply, but Step 6 tells you to prefer the project's own conventions over
generic best practice, and it cannot do that while the language, layout, imports
and test shape are still comment prompts. `scaffold` fills it for a new project,
`setup` for one that already had code.

## Step 1 - read the state

Read the project's state before acting:

- `blueprint/context/project-overview.md` - the source of truth for what this project is
- `blueprint/context/coding-standards.md` - the conventions this project's code follows
- `blueprint/context/current-work.md` - the one item in flight, if any
- `blueprint/context/findings.md` - open review findings against the current work

Then pull the conventions from `blueprint/context/coding-standards.md` and the data model from
`blueprint/context/project-overview.md` so the code matches what is already there rather than
introducing a second way of doing the same thing.

**Resuming.** If some build steps are already ticked (`- [x]`), this work was
started earlier and interrupted - often by a cleared context. The spec and its
ticked boxes are files, so nothing was lost. Read which steps are done, check the
branch and `git status` to see what is committed versus still in the working tree,
then continue from the **first unchecked step**. Do not start over, and do not
re-do a step that is already ticked.

## Step 2 - get on a branch

Create and check out a branch named from the spec: `feature/<name>` for a feature,
`fix/<name>` for a fix. If the project is not a git repository yet, stop and ask
the user to run `git init` - the loop depends on branches and on being able to
show diffs.

On a resume the branch already exists. Check it out; do not create a second one.

Never build on `main` or `master`.

## Step 3 - build one step, review, iterate

Work the spec's build steps in order, one at a time. For each step:

1. **Implement just that step** - the smallest change that satisfies its
   *done when*. Nothing from a later step, however tempting.

2. **Show the diff**, not whole files.

3. **Confirm the step actually did something, before claiming it passed.**
   **An empty diff means the step did nothing**, whatever the verification
   command says. Check it explicitly:

   - the diff is **non-empty**
   - every file the step said it would create **exists and is not empty**
   - the change landed where it was meant to, not in a path created by a typo

   This is not paranoia. A step once wrote two files into a directory that did
   not exist, both writes failed, and **the verification command still returned
   exit 0** - the test runner was set to pass with no tests, and the untouched
   template still built. Nothing about that green check was false; it simply had
   nothing to do with the step. Unattended, it would have carried the run forward
   on nothing.

   **A passing verification does not mean the step happened.** It means the
   project is in a good state, which is equally true of a step that changed
   nothing at all.

4. **Explain it in plain English.** What the step delivered, one line per changed
   file on what it does and why. This is the comprehension gate: the user should
   finish reading it able to explain the change to someone else. Keep it concrete,
   not ceremonial.

5. **Prove the done-when.** Name the evidence: build output, a passing assertion,
   a screenshot. If the project declares a verification command, run that exact
   command - it is an umbrella over checks the project actually has, so never
   invent a test runner or a check just to have something to run. A step that adds
   real logic ships its test in the same diff when a test runner is configured.
   UI and integration steps ride on a screenshot plus a green build. When a
   done-when is behavioral - a click, a download, a flow across screens - run
   `verify` against the running app rather than eyeballing it.

   **Check the done-when on its own terms, not just that the suite is green.** If
   it says "tests cover the mapping", the test count must have gone up and those
   tests must exist - a runner configured to pass with no tests reports success
   for a step that added none. If it says a string appears in the output, look for
   the string. **Match the evidence to the claim the step actually made.**

6. **Iterate until it works - but stop guessing after the second try.** If it
   fails, or the user wants it different, revise the step, show the updated diff,
   and re-check. Nothing is committed until the user is happy with the step.

   **If the same step fails twice and you cannot say why, stop and run `debug`.**
   A third attempt made without understanding the cause is a guess, and a guess
   that happens to go green is worse than the failure - it retires the question
   while leaving the cause in place. `debug` reproduces and isolates without
   touching product code, then hands the evidence back here. Say plainly that you
   do not know the cause; "I am changing this because I think it might be it" is
   the sentence that should trigger it.

7. **Tick it off, then offer the checkpoint.** Once approved, check the step off
   (`- [x]`) in `blueprint/context/current-work.md` so progress survives a context clear. If the
   step repaired a finding in `blueprint/context/findings.md`, set that finding to `fixed` and
   note the repair in its **Resolution** line - never to `closed`, because a repair
   is re-reviewed by `review` before it clears. A fix can introduce a worse
   defect than the one it removed.

   Then offer a short choice:

   - **Continue** *(default)* - straight into the next step, no commit.
   - **Commit checkpoint** - commit just this step on the branch with a
     conventional message. A cheap rollback point, entirely optional.
   - **Walk me through it** - a deeper, line-level explanation of the new code:
     why this approach, what each part does, what to watch out for. Then re-ask
     this choice. It is a loop-back, not a terminal answer.
   - **Stop here** - pause. Say where things stand: the branch is intact, the
     ticked steps record the progress, `build` resumes from the first
     unchecked step.

## Step 4 - clear the findings gate, then hand off

Before handing off, read blueprint/context/findings.md. A P0 or P1 finding still `open` or
`fixed` will block `ship`, so close the loop now:

- **Repair each open P0 or P1 as an extra reviewed step.** First append it to the
  spec's build steps (`- [ ] Repair F-03 - <title>`) so the repair is on the record
  and survives a context clear, then run it through Step 3 like any other step.
  Tick the step and mark the finding `fixed` together.
- **Then run `review`** so those repairs are re-reviewed and can move to
  `closed`. A repair never closes itself.
- **Never set `accepted` or `invalid`.** `accepted` is the user's explicit
  decision with a recorded reason; `invalid` is a `review` verdict backed
  by evidence. Neither is this skill's call.

When every step is built and the project's checks pass, stop with a compact
review packet:

- the branch name
- what changed, grouped by file or area
- checks run, with the exact command or proof used
- how to try it by hand, or a pointer to `verify`
- ledger state: any findings still `open` or `fixed`, by ID
- known risks, skipped checks, or follow-ups
- next action, usually `review` then `ship`

**In a multi-part project, post the packet** in `<product root>/blueprint/status/<this part>.md`:

    **State:** waiting
    **Item:** <the item just built>
    **Blocked on:** -
    **Review packet:** <where to read it>
    **Updated:** <today>

That path comes from `AGENTS.md`'s `Product root:` -
this part's own `blueprint/` is a different directory, and writing there means
the coordinator never sees it. The packet is not a message to nobody: the
review queue is what `autopilot` counts before starting another unattended run,
and a packet that stays in a transcript is invisible to that count. **A cap on
work nobody has posted counts to zero forever.**

**If a step cannot proceed because it needs another part**, write the block
rather than only reporting it:

    **State:** blocked
    **Blocked on:** <part> - <what is needed>

Same reason as the packet, and the same failure: `orchestrate` detects deadlock
and stale blocks by reading this field, so a block that lives only in the
conversation is one it will never find. It reports the part as building, forever.

## Rules

**Small steps, each one reviewed.** Every step ends with the app working and a
diff small enough to read in full. If a diff is too big to read in one sitting,
the step was too big - split it. That review gate is the entire point of this
workflow; batching the work into one large diff defeats it.

**Evidence, or it didn't happen.** Never report "passes", "works", or "verified"
without naming what proves it - the command and its output, the screenshot, the
response body. "I couldn't verify this" and "this failed" are useful, honest
results. A fabricated pass is worse than no check at all, because it retires the
question.

**Build only what the spec says.** If the spec is wrong, thin, or missing a case,
stop and fix the spec first - do not improvise past it. Work that nobody spec'd
is work nobody reviewed.

- **A green check is not evidence a step happened.** Confirm the diff is
  non-empty and the claimed files exist before trusting any verification result.
- **Explain every change in plain English.** Understanding the code is the point
  of the whole loop. A step the user cannot explain back has not really landed.
- **Never commit code the user has not approved.** Per-step commits are optional
  checkpoints; the work-level commit, the merge, and any push belong to
  `ship`. This skill never touches `main`.
- **Follow `blueprint/context/coding-standards.md`** over generic best practice. The project's existing
  patterns win.

## Formatting

Match the conventions in `blueprint/context/ai-interaction.md` when it exists: short, scannable
markdown, lists for enumerations, a table when comparing options. Otherwise keep
it brief and direct by the same standard. Long prose blocks are the failure mode
to avoid - this output gets read while someone is mid-task.
