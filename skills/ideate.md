---
name: ideate
description: "Turn a rough idea into a filled-in project plan by interviewing about what you are building, who it is for, and what the first version must do - then writing `blueprint/project-plan.md` and a starting build-plan.md checklist. Pushes back on scope that is too big for a first version, and names what is deliberately not being built. Use when the user runs `ideate`, is starting something new and has only a rough notion of it, or asks how to plan a project."
---

# ideate - turn a rough notion into a plan you can build from

Where this sits:

    ideate -> stack -> architect -> scaffold -> `ci` -> context -> spec

This is the very start. It runs in a project that has the workflow but no code,
no stack, and empty planning docs. **It decides what to build; `stack` decides
what to build it with.** Keep those separate - choosing a framework before the
problem is clear is how projects end up shaped by their tools.


> **In a multi-part project**, two files live at the **product root**, not in
> this part: `blueprint/project-plan.md` (the product plan) and
> `blueprint/context/quality-bar.md` (the bar the whole product is held to -
> `architect` runs at the root and writes one there, not one per part).
> `AGENTS.md` records `Product root:` - read it from there rather than assuming
> a path. Everything else named here is this part's own.

## Step 1 - understand the idea

Ask about the idea itself, not its implementation. Most of these can be answered
in a sentence:

- **What is it, in one sentence?** If that sentence is hard, the idea is not
  clear yet - and the interview is more useful than the plan.
- **What problem does it solve, for whom?** Be specific enough that it rules
  something out. "For everyone" describes nothing.
- **Who uses it** - just the user, or other people with accounts?
- **What does it need to do to be useful at all?** Not the full vision: the
  smallest thing that would actually get used.
- **What does it store**, if anything?
- **Constraints** - a deadline, a budget, something it must work with, a
  platform it must run on.
- **What already exists?** A prototype, a spreadsheet, a manual process it
  replaces. Existing things carry decisions worth knowing about.
- **What should it feel like to use?** Only if it has a UI, and one or two
  sentences is plenty: the overall feel, light or dark, and **anything the user
  is already working from** - an app whose feel they want, a screenshot, a brand
  they have to match. This is a product question, not a design exercise, and it
  is cheap to ask while they are describing the thing and expensive to
  reconstruct months later. Do not propose a visual identity here; capture
  theirs, or record that there is not one yet.

Ask only what is not already answered. If the user arrives with a clear
description, confirm your reading of it and move on rather than interrogating
them.

## Step 2 - find the first version

**The most valuable thing this skill does is cut scope.** People describe the
finished product; the plan needs the first useful version.

Sort what you heard into:

- **The core** - without this, the thing does not work at all. Usually smaller
  than the user first said.
- **Soon after** - real, wanted, and not needed to be useful on day one.
- **Later, or never** - worth naming so it stops taking up room.

Show the split and **say plainly which parts you moved out of the first version,
and why.** If the user disagrees, they are right - it is their project. But an
unchallenged first version is almost always too big, and the cost of that is
paid later, in a build that never quite finishes.

## Step 3 - propose both plans, then stop

Draft the content for the two planning docs, and show it before writing anything.

**`blueprint/project-plan.md`** - the what and why:

- the problem, the users, and the features of the first version (sections 1-3)
- what data it stores, if any (section 4)
- **constraints** (section 10) - anything that rules an option out. **`stack`
  Step 1 asks for exactly these next**, so leaving them out of the file means
  asking the user the same question twice in one sitting, and losing the answer
  entirely between sessions.
- **what is deliberately deferred, and to when** (section 11) - the output of
  Step 2, which is the most valuable thing this skill does. A cut that is not
  written down is one that gets re-litigated.
- **the UI/UX section** (section 7), if it has a UI - the feel, and any
  reference given

Leave the Tech and Architecture sections alone - `stack` and `architect` fill
those in, and guessing at them here makes their interviews harder.

**UI/UX is the opposite: fill it in.** Nothing else writes that section, and
`prototype` reads it as the direction it starts from - so an empty one means the
look gets improvised much later, by whoever happens to be building the first
screen. A rough sentence and a link to something the user likes is enough. "No
strong opinion, wants it plain" is a real answer worth recording; blank is not.

**`blueprint/build-plan.md`** - the checklist:

Turn the core into items sized to one review cycle each - a few days of work at
most, one outcome, testable on its own. Order them so each builds on the last,
and so something works as early as possible.

Good: `- [ ] 1. **Save a link** - paste a URL, store it with its title`
Not an item: `- [ ] Backend`, `- [ ] Make it good`

**Stop for approval.** These are the user's files, and everything downstream
reads them.

## Step 4 - write, and hand off

Write the approved content. Then say what comes next: `stack` to choose the
technology, and after that `scaffold` to build the project.

If anything was genuinely undecidable - a real fork the user needs to think
about - write it down as an open question in the plan rather than picking for
them.

## Rules

- **Decide what, not how.** No frameworks, no databases, no architecture. That
  is the next two skills' work, and doing it here makes them worse.
- **Cut scope, out loud.** Say what you moved and why. A first version that is
  too big is the most common way a project dies.
- **Never invent requirements.** If it was not said, it is a question, not a
  feature. Write unknowns down as unknowns.
- **Plain language.** The plan is read by a person deciding what to build, not
  only by an agent.

## Formatting

Match `blueprint/context/ai-interaction.md` when it exists: short, scannable
markdown, lists for enumerations, a table when comparing options.
