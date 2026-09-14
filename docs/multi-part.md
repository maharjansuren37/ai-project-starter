# Multi-part projects

A backend, a web front end, and a mobile app — built in parallel, one session per
part, without the sessions overwriting each other.

**Most projects should not do this.** Single session is the default and is
usually right. Read the two constraints at the bottom before choosing.

## Why parts, mechanically

`blueprint/context/current-work.md` is read or written by 11 skills, and `ship`
resets it. In a single shared blueprint, two agents collide badly: agent A is
mid-build with three steps ticked, agent B ships, the reset wipes A's spec **and
its ticked checkboxes — which are the entire resume mechanism.** A restarts from
step one having already done the work.

Giving each part its own `blueprint/` makes that structurally impossible.

## Layout

```
shop/
  AGENTS.md              the product root's own instructions
  CLAUDE.md
  .claude/ .agents/      every skill, here too — see below
  blueprint/
    project-plan.md      the product: problem, users, features, the parts
    orchestration.md     the coordination board
    status/web.md        one live-state file per part
    status/api.md
    context/ai-interaction.md
  contracts/             the boundary, owned by the part that can break it
  web/
    AGENTS.md            Part: web · Product root: ..
    blueprint/           this part's build-plan, spec, findings, history
  api/                   same shape
```

**The skills are installed at the product root as well as in each part**, because
some of them are not part work at all: `orchestrate` reads the board and every
part, and `ideate`, `architect`, `stack` and `layout` write the product plan that
lives here.
Without a copy at the root there is nowhere to run them from — and running them
from inside a part is worse than inconvenient, because an unqualified
`blueprint/` there means *that part's* blueprint, so the board would be read and
written somewhere no other part looks.

**Open the root for product-level work; open a part's directory to build in it.**
The root has no build loop — no `build-plan.md`, no `current-work.md`, no
findings ledger. Its status skill is `orchestrate`; `progress` answers the same
question inside a part.

Per-part `coding-standards.md` is deliberate: a TypeScript front end and a C#
backend have genuinely different conventions.

## Creating one

```bash
new-project.sh shop --parts web,api
```

**`--parts` takes top-level directory names.** Both this and
`convert-to-parts.sh` create every part in one pass, before `layout` has decided
anything, and what `convert-to-parts.sh` moves is keyed on a top-level name. A
nested part - `apps/web`, the shape every JavaScript workspace has - is seeded
one at a time with `lib/seed-part.sh`, which does take a path. See *adopt a
repository that was already multi-part* below; the same sequence works on a
product you are creating from scratch.

## Or convert one that already exists — usually better

Starting single and splitting once `architect` has decided the boundary is
normally the better route, **because you know more then than at the start.** The
boundary between a front end and a backend is exactly the kind of decision that
looks obvious before you have written anything and turns out differently once you
have.

```bash
cd shop
convert-to-parts.sh --parts web,api --existing web
```

`--existing` names the part this project becomes. Everything currently in the
project moves into `web/`; the product plan is lifted back to the root, the board
and the status files are created, `api/` is seeded empty, and the product root
gets its own copy of the skills. **Nothing is deleted** — the project is moved,
not rebuilt.

**Then split what was written before there were parts.** Everything part-local
moves into `--existing`, so the build plan `ideate` wrote lands in one part and
the other's is empty — and `ideate` writes the only initial item set and runs
once, at the product root. An item like *"record a loan"* is a form **and** an
endpoint; left whole it is work one part cannot finish, while `spec` in the other
part reports *nothing is queued* with its whole surface unbuilt.

The script **lists what it moved** — unchecked items, open `needs-you.md` lines,
pre-split `dev-notes/decisions.md` entries — and names `architect` as the skill
that splits them. It does not split them itself: telling a product feature from a
front-end-only one is judgement, not text processing.

It **refuses on a dirty tree or without git**, because it moves every file in the
project and the whole thing should be one diff you can review or throw away. It
also refuses if the project is already multi-part, if `--existing` is not one of
`--parts`, or if a part name collides with a directory already there.

Afterwards the result is **structurally identical to a project created with
`--parts`** — same tree, same board, same per-part fields — so nothing downstream
needs to know which route you took.

**Do not split a project by hand.** There are five things to get right — the plan
moving up, the board, the status files, each part's `Part:` and `Product root:`
fields, and the root's own skills — and missing any one of them leaves every file
individually valid while the coordination quietly does not work.

To add a further part to a product that is already split:

```bash
lib/seed-part.sh /path/to/shop mobile
```

## Or adopt a repository that was already multi-part

**A workspace that existed before this workflow did.** `convert-to-parts.sh` is
the wrong tool - it converts a *single* project by moving everything into one
part, and here the parts are already in the right places. Instead, seed the root
and then each existing directory:

```bash
install.sh --target . --skills-only
lib/seed-product-root.sh . apps/web-app apps/mobile backend shared
lib/seed-part.sh . apps/web-app
lib/seed-part.sh . apps/mobile
lib/seed-part.sh . backend
lib/seed-part.sh . shared
```

**Pass the same paths to both scripts.** They disagree otherwise: the root would
list bare names while the parts registered paths, and a five-part product came
out described as eight - three of them directories that do not exist.

**A part may be nested.** `apps/web-app` is what every JavaScript workspace looks
like, and `Product root:` is written with the right number of `..` for its depth.
**The status file and the board entry use the last segment only**, because both
are flat - so two parts whose paths end in the same name are refused rather than
silently sharing one status file.

**Nothing existing is touched.** Each part keeps its own `package.json`, `src/`
and README; the workflow adds `AGENTS.md`, `blueprint/` and the skills alongside.

**Then run `setup` in each part**, which reads the real code and records the
stack and commands that are actually there. The plans are empty until it does.

**Consider whether you want this at all.** One `blueprint/` at the root - a plain
`install.sh` with no parts - gives one build loop for the whole workspace. That
is simpler, and it is the right answer unless two sessions genuinely need to work
different parts at once. See the two constraints at the top of this guide.

## The sequence that matters more than the tooling

**1. Together, single-threaded.** `ideate`, `architect`, `stack`, `layout`, and
the contract. **Parallelising this is how three agents invent three incompatible
assumptions** that only surface at integration.

**`architect` is where the parts get decided**, and it runs before anything is
installed. If you started single, that is where you convert — the conversion
moves markdown at this point, and an installed framework with its lockfile and
dependency directory at any later one.

**2. Scaffold each part**, in its own directory, with its own scaffolder. Two
parts means running `scaffold` twice; it reads the layout `layout` recorded
and installs into it. Also set up what bridges them — the contract file in
`contracts/`, its generation step, and the one ecosystem-neutral command that
runs both parts' checks.

**3. Freeze the contract.** `orchestrate` will not move parts into parallel work
until it is frozen.

**4. Parallel.** Each part runs `spec → build → verify → review → ship` in its own
directory, one session each.

**5. `integrate`.** Every part passing its own checks is not evidence they work
together — and this is not a theoretical claim. Run for real on 2026-09-03: an
API was changed to return a new field without updating the contract. **Its
typecheck was clean. It was internally correct. The product was broken**, and
nothing but the cross-boundary check saw it.

`integrate` needs to know which kind of contract it is looking at, because the
two fail differently. A **generated** contract fails the moment the source
changes — regenerate and diff, and the difference *is* the finding. A
**hand-written** one fails only when someone runs the check, so the check is
comparing what the owner actually serves against what the document says, in both
directions: a field served but not declared is drift just as surely as one
declared but not served.

**6. A contract change stops everything.** It should feel expensive.

## The board

`blueprint/orchestration.md` **at the product root** holds the contract line and
the rules. Each part's live state is a **separate file** at
`blueprint/status/<part>.md`, also at the product root — never inside the part.

**That separation is load-bearing.** One file per part means no file has two
writers, so nothing is lost when sessions genuinely run at the same time — which
is exactly what happens when a subagent drives each part. A single shared table
would need every writer to rewrite the whole file, and two finishing at the same
instant would silently drop one. "Writes only its own row" is a convention;
separate files are a guarantee.

Read it before starting. If the contract is not frozen or your part is blocked,
stop rather than building work that gets thrown away.

**Write the block, do not just say it.** When a part stops because it needs
something another part owns, `spec`, `build` and `autopilot` record it in that
part's `Blocked on:` field, and `ship` clears it. That field is the *only* thing
`orchestrate` reads to find deadlock, a block with no owner, or a block left
standing after the thing it waited for shipped. A block that lives only in a
conversation is one the coordinator can never see — and every part will report a
confident `-` while two of them wait on each other forever.

## autopilot across parts

Runs **within one part, never across**. Its preflight gains three board checks,
each a stop: the contract is frozen, this part is not blocked, and the review
queue has room.

**It can never change the contract** — that joins `host`, production `deploy`,
and migrating real data on the permanent block list. Git can undo the edit; it
cannot undo three parts having built against different assumptions meanwhile.

## Driving parts with subagents

One session can drive several parts by giving each a subagent. Two things to know
before you do:

**A subagent running `build` is running `autopilot`.** `build` waits for your
approval on every step; a subagent cannot wait for you, it reports to the session
that launched it. Delegating `build` converts the reviewed loop into an
unattended one — make that a choice, not an accident. Give subagents an
`autopilot` range instead, which is honest about what it is.

**Give each its own git worktree.** Parts on separate branches in one working
tree fight over the index.

Subagents fit perfectly for read-only fan-out — `review full`, `preflight`'s
checks, surveying a part you do not know. The output is a report, so nothing is
skipped.

**What cannot be delegated is reading the diffs.** A subagent reporting "done" is
not a substitute for having read what it did, and the cap exists precisely
because three subagents can produce packets faster than one person reads them.

## Two constraints to decide on, not work around

**Your review attention is the bottleneck, not agent throughput.** Three parts do
not go three times faster — they go as fast as you read. This is enforced rather
than advised: **autopilot refuses to start while two packets are already waiting
for review.** Three parts each running unattended produce three self-reviewed
drafts at once, and a long autopilot run already reviews its own work. The cap
makes that state unreachable, not merely discouraged.

**Parallel work before a frozen contract is worse than sequential.** Not slower —
worse, because everything looks correct until integration.

If neither of those is comfortably true for your project, use a single session.
