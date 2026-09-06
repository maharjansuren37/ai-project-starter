---
name: stack
description: "Settle the technology stack for a new project - web app, mobile app, progressive web app, or content website. Asks the platform, then asks whether the developer already knows what they want to build with: if they do, that choice is used and only the gaps around it are filled in; if they want a recommendation, proposes one stack with its closest runner-up. Covers framework, language, styling, database, testing, and where it ships, and ends with the exact scaffold command. Writes nothing until approved; then drafts the Tech section of `blueprint/project-plan.md`, or hands the decision back as text if the workflow is not installed yet. Use when the user runs `stack`, is starting a new project, has a stack in mind and wants the rest settled around it, or asks what to build something with."
---

# stack - choose the stack before you scaffold

Where this sits:

    ideate -> stack -> `architect` -> `scaffold` -> `ci` -> `context` -> `spec`

This runs *before* there is an app. It works in an empty directory, or after the
workflow is installed while `blueprint/project-plan.md` is still being filled in.


> **In a multi-part project**, two files live at the **product root**, not in
> this part: `blueprint/project-plan.md` (the product plan) and
> `blueprint/context/quality-bar.md` (the bar the whole product is held to -
> `architect` runs at the root and writes one there, not one per part).
> `AGENTS.md` records `Product root:` - read it from there rather than assuming
> a path. Everything else named here is this part's own.

## Before you start

Read `blueprint/project-plan.md`. **If the problem, users and features sections
are still placeholder text, stop and say to run `ideate` first.** A stack picked for
a project nobody has described is a guess wearing a decision's clothes, and both
`architect` and `scaffold` build on it without re-examining it.

**If the project already has code, stop and say to run `setup` instead.** There
the stack is a fact to discover, not a choice to make.

## Input

A short description of what is being built. If the user ran this with nothing
else, ask for it: what the thing does, and anything already decided - existing
hosting, an auth provider they already pay for, a language they know well.

## Step 1 - understand the project

Ask only what changes the recommendation, in as few questions as possible.

- **Platform** - **ask this first**; it changes almost every answer after it.
  Seven, and the last three are as ordinary as the first four:

  *web app · content website · progressive web app · mobile app · **command-line
  tool** · **library or package** · **API or service with no UI***

  If the description already makes it obvious ("an iOS app for...", "a CLI
  that..."), do not ask - confirm your read of it and move on. **A project with no
  UI is not a degenerate web app**, and calling it one sends every later skill
  looking for screens that do not exist.
- **Do they already have a stack in mind?** **Ask this second, always, and
  before proposing anything.** Some people arrive knowing exactly what they want
  to build with - because they know it, because their team uses it, or because
  they want to learn it. Others want a recommendation. Both are normal, and
  guessing which one you are talking to is the mistake.

  Ask it plainly: *"Do you already know what you want to build this with, or
  would you like a recommendation?"* Accept a partial answer - "React, but I
  don't know what for the backend" - and only decide the parts they left open.
- **What it is** - one sentence, plus the core use case.
- **Who uses it** - just the user, or does it need accounts and multiple people.
- **Data** - does anything need to persist, or is it stateless.
- **Constraints** - hosting it must run on, a language or framework they already
  know and want to keep, a hard budget ceiling, app-store distribution if mobile.
  **Read section 10 of `blueprint/project-plan.md` first**: `ideate` records these
  there, and confirming what is written beats asking again. Ask only for what is
  missing, and add anything new to that section rather than keeping it in the
  conversation.
- **What it has to stand up to** - only when the answer is not obviously "very
  little". How many people at once, any latency someone would actually notice,
  whether it must work offline, and how bad an hour of downtime is. **Ask this
  before recommending, not after**: these are the constraints that rule stacks in
  and out, and a stack chosen without them is chosen against an imagined project.
  **"One user, a few hundred rows, down until I notice" is the honest answer for
  most things** - take it, say you have taken it, and let it license the simplest
  option rather than quietly building for a scale nobody asked for. `architect`
  turns these answers into the recorded bar in
  `blueprint/context/quality-bar.md`; this step only has to hear them.

Skip anything the description already answers. A static portfolio site does not
need the database question.

## Step 2 - settle the stack

Which path you take depends entirely on the answer to Step 1's second question.

### If they named a stack, use it

**Their choice wins.** Do not re-propose your own preference, do not run the
recommendation flow anyway "for comparison", and do not treat their answer as an
opening position to negotiate from. Someone who says "Flutter" has already made
this decision, and re-litigating it wastes their time and yours.

Two things you still owe them:

- **Say once if you see a real problem** - the choice cannot do something the
  project needs, it rules out a stated constraint, or it conflicts with the
  platform from Step 1 ("React Native" for a content website). One clear
  sentence, then take their answer as final. A preference you merely disagree
  with is not a problem; keep it to yourself.
- **Fill in what they left open.** A named framework rarely settles the
  database, styling, or test runner. Decide only the unanswered parts, using the
  criteria below, and say which parts were theirs and which were yours.

Then go to the checklist and the scaffold command below.

### If they want a recommendation, give one

Recommend **one** primary stack, and name the closest runner-up in a single line
so the choice is visible without turning into a menu. Five options is the same as
no recommendation.

Branch on the platform first - a mobile app and a content site share no
framework, no test runner, and no scaffold command.

- **Web app** (interactive, accounts, or API-backed) - a framework matched to
  whether it needs server rendering and API routes, or works as a client-only
  SPA.
- **Website** (content-first, little interactivity, no accounts) - prefer a
  static site generator over an app framework. Do not reach for a full React
  framework for a handful of static pages just because it is the familiar
  default.
- **Progressive web app** - the web app choice, plus an explicit PWA layer: a
  service worker, a manifest, and a stated offline strategy. What still works
  with no network, and what does not, is a decision made *here*, not bolted on
  later.
- **Mobile app** - state the cross-platform versus native tradeoff outright. One
  codebase across iOS and Android, or a single native platform for its APIs and
  feel. Default to cross-platform for a solo project unless the user already
  knows native, or the app leans hard on one platform's capabilities. Name
  app-store review as a real constraint the web platforms do not have.

- **Command-line tool** - the smallest stack in this list, and the one most often
  over-built. Language, a test runner, and an argument parser **only if the
  arguments justify one** - a single positional path does not. Say plainly when
  no framework is involved, because `scaffold` behaves differently when there is
  nothing to scaffold. Settle how it will be run during development (a script, a
  `bin` entry, a task runner) since there is no dev server to fall back on.

- **Library or package** - decide the consumers first, because they set
  everything else: what runtimes and versions must work, whether it ships types,
  and which module formats it publishes. **The public surface is the product
  here** - a library's API is far more expensive to change than an app's screen,
  so say what is exported and what is deliberately internal. Where it publishes,
  or that it stays unpublished, is a real answer.

- **API or service with no UI** - the framework, how requests are validated at
  the boundary, and **how the contract is expressed**, since the consumer cannot
  read the source. Name it here even when the consumer is a front end in the same
  product: that is what `integrate` regenerates and diffs, and a contract nobody
  named is one nothing checks.

### Either way, settle these

**Every choice includes its version.** "Next.js" is not a decision; "Next.js 15,
the current stable" is. For the framework, the language, and the runtime, settle:

- **Current stable** *(the default)* - what most projects should take.
- **A specific older version** - because something else requires it, because it
  is what the user knows, or because the newest major is too fresh for its
  ecosystem to have caught up. **A deliberately older version is a legitimate
  answer**, recorded with its reason and never quietly "corrected" later.
- Say so when a major is new enough that its ecosystem is a real risk.

**Check the version you are about to name against the runtime that is actually
installed**, before recording it - one command per runtime (`node --version`,
`python3 --version`, `dotnet --list-sdks`). Current stable is a fact about the
registry, not about this machine, and the two come apart routinely: on a real
run Node 20.18.1 was **one patch short** of what current Vite, its React plugin
and current Vitest all require, so "Vite 8, current stable" was an unbuildable
decision that read perfectly on the page.

`scaffold` makes this check too, and catching it there is not the same thing -
by then the user has approved a stack that cannot be built, and the remedy is a
second approval rather than a different first one. **Naming a version the
machine can run costs one command here.**

When the current version will not run, say so with both options and let the user
pick: **upgrade the runtime** - system software, so it is theirs to install and
belongs in `blueprint/context/needs-you.md` either way - or **pin to a version
this runtime supports**, recorded with that as the reason. Pinning two majors
back to avoid a one-patch upgrade is usually the worse trade; say which you
recommend.


- **Language** - **ask, do not assume.** Offer the platform's usual default, but
  put it to the user rather than deciding silently: someone may want plain
  JavaScript over TypeScript, a Python or Go backend behind a JS front end, or a
  language they are learning on purpose. Where a project uses more than one,
  record all of them **and which part each covers**.
- **Styling** - only if there is a UI.
- **Database** - only if Step 1 found something to persist. "None" is a real
  answer.
- **Testing** - name the stack-native runner. Setting it up happens later, not
  here: `scaffold` for a new project, `setup` for one that already had code.
- **Monitoring** - what will watch this once it is live, and **where an alert
  actually goes.** This belongs here for the same reason the test runner does:
  it is a tool with a cost, usually an account, and sometimes a constraint on the
  host. Discovering at deploy time that the chosen platform has no integration,
  or that the free tier does not cover what you need, is discovering it too late.

  **"Nothing, I will look at it when I notice" is a real answer** for a personal
  project - take it and say so, rather than adding a service nobody will read.
  So is "whatever the host provides". What is not an answer is silence, because
  then `monitor` is choosing on your behalf months later.

  **The delivery channel is the part that needs deciding now**, because it is the
  part that needs an account: email, a push service, a chat webhook. Detection is
  easy to add later; a place to send things is what a self-managed box has none
  of until someone sets one up.
- **Where it ships** - hosting for web, PWA and a service; for mobile, which
  stores if any; for a library, which registry. A sideloaded personal build, and
  **a command-line tool that is only ever run from source, are valid answers** -
  say so rather than leaving the section blank, because `host` and `deploy` read
  it to decide whether they apply at all.

Give one line of reasoning per pick you made. **Prefer boring, well-documented
tools** when the choice is yours: for a solo project the cost of learning an
unfamiliar tool usually outweighs its advantages, unless the project specifically
needs what it does. That preference guides *your* recommendations - it is not a
reason to talk someone out of a tool they chose.

### End by naming how it gets built

The `scaffold` skill installs all of this - the framework and everything the
stack implies. **Do not tell the user to run a scaffolder by hand.** It would
fail: the directory already holds the workflow files, and every framework CLI
refuses to run into a non-empty directory. `scaffold` works around that.

Name the framework's scaffolder and the pinned version, so the user knows what
`scaffold` will run, then hand off to it.

For **native mobile** there is no CLI scaffolder at all; say so, since that path
needs Xcode or Android Studio by hand.

## Step 3 - stop for approval

Show the settled stack and the scaffold command, then wait. Write nothing yet.

Mark clearly which parts were the user's own choice and which you decided, so
they know what they are actually approving. If they push back on one part ("no
database, keep it static"), revise just that part and re-confirm rather than
re-proposing everything.

## Step 4 - record the decision

Propose the exact text for the Tech section of `blueprint/project-plan.md`,
including **every version settled above**, and stop for approval before writing
it.

**And the Deployment section, section 8** - because "where it ships" was already
asked in Step 2 and the answer belongs where the skill that acts on it will look.
`host` reads that section, not Tech. Filing it under Tech is collecting the
information and putting it somewhere nobody checks.

Write what is known now, and **name what is not yet decided rather than leaving
the line out**:

- **the target host**, or "not decided" - "runs from source, not published" is a
  complete answer and stops `host` before it spends anything
- **the build and start commands**, once `scaffold` has settled them - `stack`
  can name the shape, `scaffold` corrects it to what actually landed
- **environment variables by name**, never by value. This list grows through the
  build loop; starting it here is what makes it a list rather than an
  archaeology exercise at deploy time
- **storage or a database**, if Step 2 chose one
- **a health check path**, if anything serves requests

Touch no other section.

**Record the reasoning where it will be found.** When a choice had a real
alternative and a real why - a self-hostable auth library because the plan
mentions moving off a managed host later, say - add a numbered entry to
`dev-notes/decisions.md` giving what was chosen, what lost, and what it costs. A
trade-off buried in a plan section is one nobody will read.

Then point at `scaffold` to build it.

**Record what the choices oblige you to get.** Every hosting platform,
managed database, monitoring service and registry chosen here that needs a
signup, a card or an API key goes into `blueprint/context/needs-you.md` as a
line marked *needed later*, naming the step that will need it.

**`needs-you.md` is part-local, and this skill normally runs before there are
parts** - so the file is the pre-split project's and the conversion carries it
into `--existing`, which is why `convert-to-parts.sh` lists its open lines for
splitting. If you are running this at a **product root** that is already split,
put each line in the part that will actually use the thing: `prepare`,
`progress` and `preflight` only ever read the part they are run in, so a line
left at the root is one nobody is shown. Deciding the
monitoring tool and discovering at `deploy` that its free tier does not cover
this is the failure that rule exists for.

**Then say what comes next: `architect`.** It decides code layout - one
application or two parts - and that decision turns on the languages just
chosen, which is why it runs after this and not before.

## Rules

- **Ask before proposing.** Whether the user already has a stack in mind is a
  question, never an assumption in either direction. Ask it every time.
- **A named choice is a decision, not an opening offer.** Use it. Raise a real
  problem once if there is one; never re-pitch your own preference.
- **When the choice is yours: one recommendation, not a survey.** A menu of five
  options is the same as no recommendation. Pick one, name the runner-up, say
  why, and stay open to being overruled.
- **Say who chose what.** The user should be able to see which parts of the stack
  were theirs and which you filled in.
- **Size the stack to the project.** A personal tool does not need what a product
  with a team needs.
- **Never write to a user-owned file without showing the exact text first.**

## Formatting

Match the conventions in `blueprint/context/ai-interaction.md` when it exists: short, scannable
markdown, lists for enumerations, a table when comparing options. Otherwise keep
it brief and direct by the same standard. Long prose blocks are the failure mode
to avoid - this output gets read while someone is mid-task.
