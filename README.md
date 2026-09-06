# AI Project Starter

One command creates a project directory with every skill already in it. Open it
with Claude Code — or any AI coding tool, or nothing at all — and the whole
lifecycle is there: ideate, stack, scaffold, build, ship, host, deploy, monitor.

> **Inspired by [ai-blueprint](https://github.com/bradtraversy/ai-blueprint) by
> [Brad Traversy](https://github.com/bradtraversy)**, MIT licensed. The workflow
> design is his; the content here is written from scratch. See
> [Credit](#credit).

```bash
~/ai-project-starter/new-project.sh my-app
cd my-app
# open it with your AI tool and run: ideate
```

The command **creates** the directory. That is the point — there is never a
moment where you have a tool open in an empty folder with no skills in it.

### Where it creates it

By default, in your current directory. Any of these work:

```bash
new-project.sh my-app                # ./my-app
new-project.sh projects/my-app       # ./projects/my-app
new-project.sh ~/code/my-app         # /home/you/code/my-app
new-project.sh my-app --in ~/code    # /home/you/code/my-app
```

It refuses rather than guessing when the target already exists, when the parent
directory does not, or when an absolute path is combined with `--in`.

## What you get

```
my-app/
├── README.md          what it is, how to run it
├── AGENTS.md          entry point every AI tool reads
├── CLAUDE.md          imports AGENTS.md
├── dev-notes/         why it is shaped this way, and where it stands
├── blueprint/         plans, the current spec, findings, history
├── .claude/skills/    26 skills for Claude Code
└── .agents/skills/    the same 25 for everything else
```

**No source directory yet** — that is deliberate. `scaffold` creates it once
`stack` has decided what the project is built with and `architect` has decided
its layout, using the framework's own conventions rather than one imposed here.

## The loop

```
ideate → stack → architect → scaffold → ci → context  plan it
     → prototype                                    settle the look (optional)
     → spec → build → verify → review → ship        build it
     → preflight → host → deploy → monitor          run it
```

| | |
|---|---|
| **Plan** | `ideate` `stack` `architect` `scaffold` `ci` `context` |
| **Design** | `prototype` |
| **Build** | `spec` `build` `verify` `review` `ship` |
| **Operate** | `preflight` `host` `deploy` `monitor` `migrate` `integrate` |
| **Learn** | `monitor` back into the plan, `docs` for release notes |
| **Support** | `setup` `progress` `prepare` `debug` `docs` `rollback` `autopilot` `orchestrate` |

No framework is assumed. `stack` asks what you want to build with — language and
version included — and `scaffold` installs it, whether that is Next.js, Astro,
Expo, Flutter, or nothing at all.

## What holds it together

**Every piece of state is a file.** A session that starts cold is the normal
case, not a degraded one — the plans, the current spec with its ticked steps, and
the open findings all load automatically, so "continue" picks up at the first
unchecked step without any conversation history.

**Findings have teeth.** `review` records them with durable IDs and a status; an
`open` *or* `fixed` P0/P1 blocks the merge. `fixed` blocking is deliberate — a
repair isn't done until a review has seen the result.

**Evidence, or it didn't happen.** "Passes" names a command, output, or
screenshot. "I couldn't verify that" is a valid answer.

**Two different questions get asked.** `ship` asks "is this change safe to
merge?" `preflight` asks "is this product ready to be live at all?" — the whole
project, once, before launch. It can say no, and that is the point.

**The project records its own bar, and later checks measure against it.**
`architect` writes what performance, scale, security and availability this
project holds itself to; `scaffold` writes the conventions the code actually
follows; `prototype` writes the design decisions and the contrast values it
measured. Without those, `review`'s lenses can only report generic smells —
**a clean result then means "not checked", not "consistent"**, and the skills say
so rather than letting silence read as a pass.

**Every skill checks its inputs before it acts.** Each opens by naming what must
already be true and what to run when it is not. Some stop; some report and carry
on. **A skill stopping is it working** — it is refusing to build confident output
on an empty file.

**Work only a person can do is recorded, not just mentioned.** Six skills write
to `blueprint/context/needs-you.md` the moment they hit something an agent
cannot do — an account, a card, an SDK, a device, a decision, a permission —
each with what it blocks and when it is needed. `prepare` reports it, `progress`
says when the next action is yours, and `preflight` treats anything open and
required as a blocker. Without it the only way to discover you needed a paid
account was to run the skill that spends money and watch it refuse.

**Standards have two owners and never share a file.** The conventions that hold
regardless of stack are the pack's, refreshed on every install so improvements
reach projects that already exist. Everything specific to your project is yours
and is never overwritten — **and where they disagree, yours wins.**

**Every place the code runs is written down.** `AGENTS.md` carries a table of
environments — what each is for, where its configuration comes from, and
**whether it holds data anyone would miss.** `deploy` names its target from it and
`migrate` reads it before touching a schema, treating anything unrecorded as
holding real data.

## Guides

| | |
|---|---|
| **[docs/walkthrough.md](docs/walkthrough.md)** | Start to shipped, for an ordinary single project. **Read this first.** |
| **[docs/mobile.md](docs/mobile.md)** | The mobile route, and where it differs from web |
| **[docs/multi-part.md](docs/multi-part.md)** | A backend and front ends built in parallel, one session per part |
| **[docs/anatomy.md](docs/anatomy.md)** | How each part does its job — what it reads, writes, and gates on. For changing the workflow, not using it |

## Building several parts in parallel

```bash
new-project.sh shop --parts web,api          # from scratch
convert-to-parts.sh --parts web,api --existing web   # or split an existing one
```

Each part gets its own loop and its own state, so parallel sessions cannot
overwrite each other. They coordinate through a board at the product root, and
`integrate` checks the parts actually agree — which is what per-part verification
cannot tell you.

**Converting is usually the better route**, because the boundary is a decision
you understand properly only once `architect` has run. The two produce the same
structure, so nothing downstream depends on which you used.

**Most projects should not do this.** Single session is the default and usually
right; see the guide for the two constraints that decide it.

## Which tools this works in

Skills install to `.claude/skills/<name>/SKILL.md` and `.agents/skills/<name>/SKILL.md`
— the same file, fanned out from one source. `AGENTS.md` is the entry point;
`CLAUDE.md` imports it, so there is one source of truth.

**[opencode](https://opencode.ai)** reads `AGENTS.md` (and prefers it over
`CLAUDE.md` when both exist), and finds the skills in `.agents/skills/` without
any extra install — verified with `opencode debug skill`, which lists all 25.

But **loading a skill is not the same as being able to type `/spec`.** opencode
has no `/name` for a skill; the model picks one by matching your request against
its description. This pack's whole documented UX is "run `spec`", so `install.sh`
also writes `.opencode/command/<name>.md` — one thin wrapper per skill, in
opencode's own command format. Those are wrappers, not copies: the skill body
stays the single source. `opencode debug config` shows all 25 registered.

So in opencode you can type `/spec`, and in Claude Code `/spec`, and both reach
the same file.

Its frontmatter rules are what `check.sh` enforces: `name` lowercase with single
hyphens matching the directory, `description` at most 1024 characters. A skill
that breaks either does not report an error — **it silently does not load**,
which looks exactly like the agent choosing not to use it.

Anything else that reads `AGENTS.md` and plain markdown works too; the skills use
plain names for cross-references rather than any tool's `/command` syntax, which
is why they read correctly everywhere.

## Adding it to a project that already exists

```bash
cd existing-app
~/ai-project-starter/install.sh
```

Then run `setup`, which reads the real repo — stack, versions, commands — and
records what is actually there. It never installs or upgrades anything.

## Updating

```bash
install.sh --force
```

Re-copies the skills. **Files you own are never touched**, with or without
`--force`: the plans, the specs, `dev-notes/`, `AGENTS.md`. If you edited a skill
and want the new version, `--force` overwrites it and git shows you what changed.

No manifest, no conflict detection, no backups. That is a deliberate trade at
this size — the repo is the version control.

## Using it without an AI tool

Every skill is a numbered worksheet. Open `.claude/skills/spec/SKILL.md` and work
through `## Step 1`, `## Step 2` yourself. Cross-references are plain names, so
they read correctly on paper. Skip the approval gates — those exist so an agent
stops before writing to a file you own, and doing it yourself you already have.

## Working on this repo

```bash
./check.sh
```

Validates frontmatter, that each skill's name matches its filename, that step
numbers run in order, and that **no skill refers to another by tool-specific
syntax** — `/spec` or `$spec` instead of a plain name. That last one is not
theoretical: a rename left stale `/status` references in a predecessor of this
repo, wrong for every tool but one, and nothing caught it.

It also checks the things that span files rather than living in one, because
that is where every serious bug here has been: **no skill is unreachable**,
**every script is referenced** by some doc or skill or other script, **every
field on the coordination board has a writer**, **every state file the skills
read has a declared writer that really writes it**, **every skill states its
preconditions**, and **every file that lives at the product root is named as
such** by each skill that reads it. A skill nothing routes to, a script nothing
mentions, a field every reader sees as permanently empty, and a path that
resolves to the wrong directory inside a part are all invisible to a
file-by-file check — and every one of them has actually shipped.

**Each of those is driven by a list in `template/AGENTS.md`, not by cleverness.**
That is the pattern worth copying: a class becomes checkable at the moment it is
written down. The path one was recorded here as unlintable for months, and
became rule 13 the day the product-level files were declared — which promptly
found five more skills reading a plan that does not exist inside a part.

Skills live in `skills/`, one file each. `install.sh` fans them out to both
adapter directories, so there is only ever one copy to edit and the two trees
cannot drift.

The scripts:

| | |
|---|---|
| `new-project.sh` | create a project, single-part or `--parts` |
| `install.sh` | add the workflow to a project that already exists |
| `convert-to-parts.sh` | split a single-part project into a multi-part product |
| `check.sh` | lint the skill sources |
| `tests/run.sh` | run the test suite |
| `lib/seed-part.sh` | seed one part; also adds a part to an existing product |
| `lib/seed-product-root.sh` | seed a product root |
| `lib/retired-names` | names this pack used to have — read by both `check.sh` and `install.sh` |

The two `lib/` scripts exist because `new-project.sh --parts` and
`convert-to-parts.sh` must produce **exactly** the same shape. Sharing them is
what makes that true by construction rather than by two implementations agreeing
for as long as nobody edits one of them.

### Upgrading a project

`install.sh` over an existing project is the upgrade path, and it draws one line
throughout: **what the pack owns, it replaces; what you own, it never touches.**

- **Skills are always replaced.** `skills/` is the one source and install fans it
  out, so an installed copy is a generated artifact — and a stale skill is
  invisible, loading and behaving exactly like a current one.
- **The opencode command wrappers are always rewritten too.** They are generated
  from each skill's frontmatter, so they are pack-owned for the same reason —
  and a stale one is the visible copy, since opencode shows the wrapper's
  description in its command menu and matches requests against it.
- **Skills the pack retired are removed by name**, from `lib/retired-names`.
  Anything else it does not recognise is **reported and left alone** — it is
  yours.
- **`blueprint/context/fundamentals.md` is refreshed**, so improvements reach
  projects that already exist. Your `coding-standards.md`, plans and state files
  are never overwritten.
- **A shape the pack no longer produces is named, never rewritten** — along with
  the skill that fixes it. Merging needs judgement a script has not got.

### Tests

```bash
./tests/run.sh
```

`tests/lib.sh` holds the assertions; `tests/test-lint.sh` negative-tests every
linter rule, `tests/test-scripts.sh` runs the scripts and checks what they
produced, and `tests/test-seams.sh` checks the invariants that span files -
which is where every serious defect here has been.

The runner **fails three assertions on purpose before running anything else**,
to prove the harness reports a failure. A rule in this repo once shipped unable
to fail, and a test suite with that flaw hides every defect beneath it.

## Credit

**This is inspired by [ai-blueprint](https://github.com/bradtraversy/ai-blueprint)
by [Brad Traversy](https://github.com/bradtraversy)**, MIT licensed.

The workflow design is his — the `blueprint/` directory layout, the findings
ledger, and the plan → spec → build → verify → review → ship loop. Those are the
ideas that make this work, and they came from there.

What is different here is scope and mechanics rather than concept: the lifecycle
continues past merge into `preflight`, `host`, `deploy` and `monitor`;
cross-references are plain names so no generator is needed; and multi-part
products get per-part state and a coordination board. The skill text, the
scripts, the linter and the tests are written from scratch.

**If you find this useful, the original is worth your time.**
