---
name: architect
description: "Turn an approved stack and the problem, users, and features already in `blueprint/project-plan.md` into a concrete structure: routes and pages for a web app or PWA, screens and navigation for a mobile app, or a page list for a website - plus the data model, where logic lives, the auth boundary, and any third-party service a feature actually needs. Sized to the project's real scope. Proposes exact edits to the plan's Architecture section and stops for approval before writing. Use when the user runs `architect`, has a stack chosen and needs structure before building, or asks how to structure a new project."
---

# architect - design the structure before you build

Where this sits:

    `stack` -> architect -> `scaffold` -> `ci` -> `context` -> `spec`

Run this once the stack is settled and `blueprint/project-plan.md`'s problem, users,
and features have real content - **and before `scaffold` installs anything.**

**That order matters and it used to be the other way round.** `scaffold` builds
into a layout: one application, or two parts in their own directories. This skill
is what decides which. Scaffolding first means installing into a layout nobody
has chosen yet, and then either living with the guess or moving a fully installed
project afterwards.

Skipping it is fine for a small enough project; `context` will generate
from whatever the plan already says, and `scaffold` will assume one application,
which is the right default. The point of running it is to make the
structural decisions deliberately rather than discovering them halfway through
the third feature.


> **In a multi-part project**, two files live at the **product root**, not in
> this part: `blueprint/project-plan.md` (the product plan) and
> `blueprint/context/quality-bar.md` (the bar the whole product is held to -
> `architect` runs at the root and writes one there, not one per part).
> `AGENTS.md` records `Product root:` - read it from there rather than assuming
> a path. Everything else named here is this part's own.

## Before you start

If `blueprint/project-plan.md` does not exist, or its problem and features sections are
still placeholder text, **stop and say so**. This skill designs structure for a
defined idea; it does not invent the idea.

**If the Tech section is still empty, stop and say to run `stack` first.** Code
layout and the data model are decided against a known language and framework;
deciding them first means deciding them twice.

## Input

No argument. Reads `blueprint/project-plan.md` and blueprint/build-plan.md.

## Step 1 - read what is already decided

Pull the problem, users, features, and Tech section from `blueprint/project-plan.md`,
and the item list from `blueprint/build-plan.md` if it has entries.

That is the brief. Do not re-ask questions it already answers.

## Step 2 - size the design to the project

Before designing anything, judge the real complexity from the feature list.
**A handful of CRUD screens is not a system that needs service boundaries, a
message queue, or a diagram with more than six boxes.** Match the depth of the
design to what is actually being built.

Say explicitly when something does not apply - "no background jobs needed" -
rather than staying silent or inventing scope to fill a heading.

Design only what the project needs, from:

- **Code layout** - **decide this first, because everything else sits inside it.**
  Three shapes, and they are not equally likely:
  - *One application* - a single source root, usually `src/`. **This is the
    default and most projects should take it**, including anything with server
    routes inside the same framework. Splitting is easy to do and expensive to
    undo.
  - *Two parts in one repository* - a front end and a separate backend, often
    because they are different languages. Say where each lives (`web/` and
    `api/`, or `apps/web` and `apps/api`), **how they share types across the
    boundary**, how both run together in development, and whether they deploy
    together or apart. That last question is the one people forget and then
    discover at deploy time.
  - *Separate repositories* - only when the parts genuinely release on
    independent cycles or different people own them. For a solo project this is
    almost always wrong: it doubles the tooling and makes a change spanning both
    a two-repository dance.

  **Config files stay at the root of whichever part owns them**, because that is
  where their tools look.

  **Choosing more than one part means choosing coordination.** Each part gets its
  own loop and its own state so parallel sessions cannot collide, and they
  coordinate through the board that `orchestrate` maintains. Say so here, and say
  who owns the contract - usually the backend, because it is the part that can
  break it.

  **If this project is currently single-part, choosing parts is a conversion, and
  it does not happen by itself.** Splitting a project by hand goes wrong quietly:
  the product plan has to move up, the board and the status files have to be
  created at the product root, each part's `AGENTS.md` needs its `Part:` and
  `Product root:` fields, and the product root needs its own copy of the skills
  or there is nowhere to run `orchestrate` from. Miss any one and every file
  still looks correct while the coordination silently does not work.

  So **stop here and say what has to be run** - the pack's
  `convert-to-parts.sh`, from wherever the pack itself is installed:

      convert-to-parts.sh --parts web,api --existing web

  `--existing` names the part this project becomes; everything currently here
  moves into it, and nothing is deleted. It refuses on a dirty tree, because the
  whole conversion should be one diff that can be thrown away. **Do not attempt
  the move by hand instead** - and do not carry on designing against parts that
  do not exist yet.

  **This is cheap here and expensive later**, which is the reason this skill runs
  before `scaffold`. Right now the project is planning files and nothing else, so
  the conversion moves a handful of markdown. After scaffolding it moves an
  installed framework, its lockfile and its dependency directory - and then each
  part still has to be scaffolded separately anyway. Convert first, scaffold
  into the parts second.

  **Then split the build plan across the parts - this does not happen by
  itself.** The conversion moves everything part-local into `--existing` and
  seeds the others empty, so every item `ideate` wrote lands in one part. Those
  items describe the **product**: "record a loan" is a form *and* an endpoint,
  and left whole it is an item one part cannot finish. Meanwhile the other part's
  plan is empty, so `spec` run there reports *nothing is queued* while its entire
  surface is unbuilt.

  So rewrite each product item as the part-sized items it implies, in each part's
  own `blueprint/build-plan.md`, and say which came from which. **`ideate` is the
  only skill that writes an initial item set and it runs once, at the product
  root** - after the split, nothing else will do this. Check the same way for
  anything else written before there were parts: open `needs-you.md` lines belong
  to the part that uses the tool, and `dev-notes/decisions.md` entries that are
  product-wide belong at the root. The conversion script lists what it moved for
  exactly this reason.

- **When the two parts do not share an ecosystem** - a React front end with an
  ASP.NET, Django, or Rails backend - three things that are free within one
  ecosystem become real work, and **each needs an answer here rather than at
  deploy time**:
  - *Sharing types* - there is no package both can import. Generate from a
    contract instead: the backend emits an OpenAPI document, the front end
    generates its client from it, and **the generation runs as part of the
    build** rather than by hand. Hand-writing the types on both sides drifts
    silently the first time a field changes.
  - *One verification command* - an npm script cannot run `dotnet test`. Put
    something ecosystem-neutral above both - a `Makefile` or a small script -
    with each part keeping its own native command underneath.
  - *Running both in development* - no workspace tooling spans them. A process
    runner, `docker compose`, or two terminals. **Two terminals is a legitimate
    answer**; leaving it unstated is not.

  Also decide **which part owns the contract**. Usually the backend, because it
  is the one that can break it.

  **And say where it lives, by name.** The contract goes in `contracts/` at the
  **product root** - not inside the owning part, because a file inside `api/`
  reads as `api`'s private business when it is the one thing both parts are
  bound by. Record the actual filename (`contracts/openapi.yaml`,
  `contracts/schema.graphql`), the command that regenerates it, and the command
  each consumer runs to generate its client.

  **A contract nobody can name is a contract nobody checks.** `integrate` and
  `ci` both regenerate it and fail on a difference; neither can do that against
  "the contract file" in the abstract. Write the paths into `AGENTS.md` with the
  other commands.

- **Inside a source root** - say how it is organised, because "we will see"
  becomes a different answer in every file:
  - *Flat* - a handful of modules beside each other. Right for something small;
    do not build folders for four files.
  - *By feature* - `bookmarks/`, `folders/`, each holding its own UI, logic, and
    types. Scales with the number of features and keeps a change in one place.
  - *By layer* - `components/`, `hooks/`, `lib/`, `types/`. Familiar, but a
    single feature ends up scattered across every folder.

  Pick one, name it, and say when it should change. **Starting flat and moving to
  features when it hurts is a legitimate and common answer** - just say that,
  rather than leaving it undecided.

- **Structure** - branch on the platform recorded in the Tech section. In a
  two-part project, apply this per part - the front end has routes or screens,
  the backend has endpoints.
  - *Web app or PWA* - routes and pages, following the framework's own
    conventions. For a PWA, the service worker's cache strategy and offline
    fallback belong here too: they are structure, not a later addition.
  - *Mobile app* - screens and navigation structure, not routes. Name any device
    capability a feature actually needs - camera, location, notifications,
    local storage - and only those.
  - *Website* - often just a page list and where it is hosted. Say that outright
    rather than forcing a routing design onto six static pages.
- **Data model** - the core entities, their fields, and how they relate, at the
  level of detail someone could write a schema from. Not full DDL.
- **Where logic lives** - and why. On web, the choice between server-side
  handlers, API routes, or nothing at all for a static site. On mobile, there is
  almost always a real API to call, so name what the client talks to and where
  that backend runs.
- **Auth boundary** - if there are users: where authentication happens and what
  is gated behind it. "None" is a valid answer for a single-user tool.
- **Integration points** - third-party services a feature in the plan actually
  requires. Only those. A payments integration for a project with no paid feature
  is scope invented by the architecture.

## Step 3 - system design, only if the project crosses a line

Everything above is **application** architecture, and for most projects it is the
whole job. This step asks whether more is genuinely needed.

**Ask whether any of these is true:** more than one deployable service · work
that must happen outside a request · data that must stay consistent across more
than one write · a dependency whose failure is not acceptable · real load or a
hard latency target · an external API that is rate-limited or unreliable.

**If none of them is, say so explicitly and stop here.** "Single process, one
database, no background work" is a complete and correct system design for most
things, and stating it prevents a speculative queue or cache being added to a
project that needs neither.

If any is true, decide:

- **Async and background work** - what runs outside the request, what triggers
  it, and what happens if it fails or runs twice. Idempotency belongs here.
- **Failure modes** - for each external dependency, what happens when it is down
  or slow: retry with backoff, degrade, queue, or fail loudly. Choose, deliberately.
- **Caching** - what is cached, where, for how long, and **how it is
  invalidated**. Invalidation is the part that gets skipped and the part that
  causes the bugs.
- **Consistency** - which operations must be atomic, where a transaction is
  needed, and what may briefly be out of date.
- **Rate limits** - both directions: what the APIs you call impose on you, and
  what you must enforce on your own callers.
- **Service boundaries** - only with more than one deployable unit: what each
  owns, how they talk, and what happens when one is unavailable.
- **Scaling limits** - what breaks first, and roughly at what load. An honest
  ceiling beats an architecture that pretends to be infinite.
- **What must be measurable** - the few signals that would reveal each failure
  mode above. **This is the direct input to `monitor`**, and `preflight` later
  checks whether they were actually wired up, so observability gets designed
  rather than retrofitted after the first outage.

**Write down what does not apply, with the reason.** Silence is what lets an
invented queue creep in, and equally what lets a real failure mode go
unconsidered.

## Step 4 - record the quality bar

Step 3 asked whether this project has real load or a hard latency target. **Write
the answer down as a number, including when the answer is "no".** Asking the
question and discarding the answer is why `review`'s performance lens can only
report generic smells - `N+1`, unbounded collection - and can never say *this
exceeds what the project said it would accept*.

Write `blueprint/context/quality-bar.md`. Keep it short; every line must be
something a person or a command could check:

- **Performance** - the one or two numbers that matter, and **where they are
  measured**. "Search results under 500ms at p95, measured server-side" is a bar.
  "Fast" is not.
- **Scale** - the load this is actually built for. "One user, a few hundred rows"
  is a real and useful answer, and it is the honest one for most projects. It
  licenses simple choices later instead of leaving them looking careless.
- **Security posture** - what this handles and what that obliges. Whether there
  is authentication, whether any data is personal or regulated, whether secrets
  go anywhere but environment variables.
- **Availability** - what happens when it is down, and for how long that is
  tolerable. For most personal projects "it is down until I notice" is correct;
  say it, so nobody builds failover nobody wanted.

**Accessibility belongs in `blueprint/context/design.md`, not here** - `prototype`
owns that bar and records the contrast values it actually measured. Point at it
rather than restating it, so there is one owner per concern.

**A bar nobody can check is worse than none**, because it reads as rigour while
resolving no argument. If a number cannot be justified, write "not measured, no
target" - `preflight` treats that as a knowingly-accepted risk, which is a real
outcome, rather than pretending a target exists.

**Then check the stack against it.** `stack` asked what this has to stand up to
before recommending, so usually the answer holds and one line saying so is enough.
**When it does not - the bar needs something the chosen stack cannot give - say so
and route back to `stack`.** That is a technology decision surfacing one step
late, and it is far cheaper here than after `scaffold` has installed it.

Re-run this step whenever the answer changes. `setup` writes this file for a
project that already existed, by measuring what is true rather than choosing it.

## Step 5 - stop for approval

Show the proposed structure and the exact text you would add to
`blueprint/project-plan.md`'s Architecture section. Wait.

On pushback, adjust and re-show the whole section rather than applying it
partially.

## Step 6 - write the approved edit

Write only the approved text, only into the Architecture section. Leave the
problem, users, features, UI/UX, and deployment sections alone - those are the
user's own planning pass.

**Add to the Deployment section anything the structure just decided.** `stack`
started it; the consequences of *this* skill's choices belong there too - storage
a feature needs, a health check path if something serves requests, and for a
multi-part project, whether the parts deploy together or separately. **That last
one is the question people discover at deploy time**, and it is settled here.

Write `blueprint/context/quality-bar.md` from Step 4 at the same time, and say in
your report that you did - it has readers in `spec`, `verify`, `review` and
`preflight`, and an unwritten one silently removes the project's own standard from
all four.

**In a multi-part product that is `<product root>/blueprint/context/quality-bar.md`,
and there is one.** This skill runs at the product root, so an unqualified
`blueprint/` here is already the root's - but every one of those four readers runs
*inside a part*, where the same string means that part's own directory. Say the
qualified path in your report so nobody looks in the wrong place, and **do not
write a copy into each part**: scale, security posture and availability are facts
about the product, and two copies of a bar is how two parts end up held to
different standards. Where a number genuinely differs per part - a latency budget
for the API, a render budget for the front end - say so per part inside the one
file.

**Record the reasoning where it will be found.** When a structural choice had a
real alternative and a real why, add a numbered entry to `dev-notes/decisions.md`
saying what was chosen, what lost, and what it costs. A trade-off buried in a
plan section is one nobody will read.

Then say what is next. **`scaffold` comes next in every case** - it acts on the
code layout just decided, and installing a framework into a layout that is about
to move is the expensive way round. `context` follows it.

Then **branch on whether this project has a UI worth settling before the build
loop starts**:

- **It has real screens** - name `prototype` after `context` and before the first
  `spec`. It reads `blueprint/context/project-overview.md` for what the screens
  must show, and `context` is what generates that, so it cannot usefully run
  earlier. Deciding what something looks like *while* building it is expensive;
  deciding it first in throwaway HTML costs almost nothing to redo. Skipping it is
  a legitimate choice, but it should be a choice, not something nobody mentioned.
- **It has little or no UI** - an API, a CLI, a library - go straight from
  `context` to `spec` and say why `prototype` does not apply.

## Rules

- **Size it to the project.** The most common failure here is designing for a
  scale the project will never reach. Fewer boxes.
- **Say what does not apply.** An explicit "no queue needed, this is one user"
  is more useful than silence, and stops the question being re-litigated later.
- **Only what a planned feature needs.** If nothing in the plan calls for it, it
  is not in the architecture.
- **Never write outside the Architecture section.**

## Formatting

Match the conventions in `blueprint/context/ai-interaction.md` when it exists: short, scannable
markdown, lists for enumerations, a table when comparing options. Otherwise keep
it brief and direct by the same standard. Long prose blocks are the failure mode
to avoid - this output gets read while someone is mid-task.
