---
name: context
description: "Validate the two planning docs and generate `blueprint/context/project-overview.md` from them - the AI-facing source of truth loaded every session. Checks the plans for shape problems first (placeholder text, a build plan that is not a checklist, features that contradict the stack) and proposes fixes before generating. Use when the user runs `context`, has just finished writing or editing the plans, asks to regenerate the overview, or after any plan change that affects direction, data, or stack."
---

# context - generate the source of truth from the plans

Where this sits:

    `blueprint/project-plan.md` + `blueprint/build-plan.md` -> context -> `blueprint/context/project-overview.md`

You own the two planning docs. This distills them into one file the agent loads
every session. The direction is one-way on purpose: **edit the plans and
regenerate, never hand-edit the overview.** A hand-edit is lost on the next run
and, worse, silently disagrees with the plans until then.


> **In a multi-part project**, two files live at the **product root**, not in
> this part: `blueprint/project-plan.md` (the product plan) and
> `blueprint/context/quality-bar.md` (the bar the whole product is held to -
> `architect` runs at the root and writes one there, not one per part).
> `AGENTS.md` records `Product root:` - read it from there rather than assuming
> a path. Everything else named here is this part's own.

## Before you start

**If `blueprint/project-plan.md` or `blueprint/build-plan.md` does not exist, stop
and say to run `ideate` first.** This skill distils the plans; it does not write
them.

Step 2 checks the plans for shape problems and is the real gate - a half-template
plan generates an authoritative-looking overview full of nothing, and every skill
downstream reads that file as the source of truth.

## Step 1 - read both plans

Read `blueprint/project-plan.md` and `blueprint/build-plan.md` in full. Also read
`blueprint/context/project-overview.md` if it already exists, so you can report what your regeneration
changes.

## Step 2 - validate the shape, before generating anything

Generating a confident overview from a plan that is still half template produces
an authoritative-looking file full of nothing. Check for:

- **Placeholder text.** Sections still holding the seeded instructions rather
  than the user's own content.
- **A build plan that is not a checklist.** If items are plain bullets with no
  `- [ ]`, the loop cannot track progress. Propose the checkbox version.
- **Items that are not item-sized.** "Auth, billing, and dashboard" on one line
  is three items. "Make it nice" is not an item at all.
- **Contradictions.** A feature the stack cannot support, data in the model that
  no feature reads or writes, an architecture describing a platform the Tech
  section does not name.
- **Missing decisions the build will immediately need.** No stack at all, or no
  data model while half the features store things.

Report what you found. For anything mechanical - checkbox conversion, splitting
an oversized item - propose the exact replacement text and get approval before
writing it.

**A contradiction the user has to resolve stops this skill.** Do not generate an
overview from plans that disagree with themselves, and do not pick a side on
their behalf. Say what conflicts and ask.

## Step 3 - generate the overview

Write `blueprint/context/project-overview.md`, covering:

- **What this is** - the problem, in the user's own framing, and who it is for.
- **Scope** - what the first version includes, and what is explicitly deferred.
- **Stack** - the chosen technologies and the reasoning that survived from the
  plan. An agent reading this should not re-litigate a settled decision.
- **Architecture** - structure, data model, where logic lives, the auth boundary.
- **Constraints** - anything that rules an approach out: hosting, budget, a
  platform requirement, an existing system it must fit.
- **Current state** - which items are checked off, what is in flight, what is
  next.

Write it for an agent joining with no other context. Prefer concrete detail over
summary: this file replaces reading everything else, so vagueness here becomes
vagueness in every session that loads it.

Mark it as generated at the top, with the instruction to edit the plans instead.

## Step 4 - report what changed

If an overview already existed, say what this regeneration changed - new items,
a changed stack, a resolved contradiction. If this is the first generation, say
so.

Then point at what is next:

- `architect` if the architecture section is still thin
- **`prototype` if the first item is a screen and no visual reference exists** -
  building a design from prose alone is how an approximation lands and then
  becomes what the app permanently looks like
- otherwise `spec` to start the first item

## When to re-run

- After editing either planning doc.
- After `spec` adds a new item to the build plan.
- After anything that changes direction, users, data, stack, or deployment.

It is cheap and idempotent. Re-running it when nothing changed produces the same
file.

**Check the build plan describes *this* product before generating anything.**
Placeholder items shipped in the template for a long time, and a project that
never deleted them carries items for a product that does not exist. Every skill
reading that file treats an unchecked box as real work - `spec` specs the first
one, `progress` counts it as remaining, `prepare` files a requirement for a
service it names. **The tell is an item that does not match the plan's own
description of the product**, and the answer is to stop and say so rather than
generate an overview around it: an overview built on the wrong items is
confidently wrong in the one file every other skill trusts.

## Rules

- **Never invent content the plans do not support.** A gap in the plan is
  reported as a gap, not filled in with something plausible.
- **Never hand-resolve a contradiction.** Stop and ask.
- **The overview is generated, the plans are owned.** Never edit
  `blueprint/project-plan.md` or `blueprint/build-plan.md` without showing the exact change
  and getting approval first.

## Formatting

Match the conventions in `blueprint/context/ai-interaction.md` when it exists: short, scannable
markdown, lists for enumerations, a table when comparing options. Otherwise keep
it brief and direct by the same standard. Long prose blocks are the failure mode
to avoid - this output gets read while someone is mid-task.
