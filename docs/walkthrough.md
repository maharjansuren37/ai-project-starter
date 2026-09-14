# Start to shipped

The ordinary path: one project, one session, idea to running in production. Every
command you actually type, in order, and what to expect at each gate.

For the mobile route see [mobile.md](mobile.md); for building several parts in
parallel see [multi-part.md](multi-part.md).

## 1. Create the project

```bash
~/ai-project-starter/new-project.sh my-app
cd my-app
```

The command creates the directory with all 27 skills already inside, so when you
open your AI tool everything is there. There is deliberately **no source
directory yet** — `scaffold` creates it once `stack` knows what this is.

Then open the directory with your AI tool. **How you invoke a skill depends on
the tool**, and this is the one thing that trips people up:

| Tool | How you run a skill |
|---|---|
| **Claude Code** | `/spec` — skills appear as slash commands |
| **opencode** | `/spec` — `install.sh` writes `.opencode/command/` wrappers for exactly this |
| **Anything else reading `AGENTS.md`** | say it in prose: *"run spec"*. The skills are in `.agents/skills/`, and each description ends with when to use it |

If `/spec` does nothing after an install, **quit and restart the tool** — opencode
and most others load commands and skills once at startup and do not reload them.

## 1b. What every skill does before it acts

Each skill opens with a **`## Before you start`** section naming what must already
be true. Two kinds, and knowing which you are looking at saves confusion:

- **Blocking** — it stops. *"Run `spec` first"*, *"the Tech section is still
  placeholder"*. Proceeding would build confident output on an empty file, which
  is much harder to spot later than an error.
- **Advisory** — it says what is missing and carries on. `review` telling you
  `coding-standards.md` was never written is the difference between "checked and
  consistent" and "there was nothing to check against".

**A skill stopping is it working.** `ideate`, `setup`, `progress`, `preflight`,
`debug` and `docs` have no preconditions by design — they are the entry points
and the read-only reporters, and they work in any state.

## 2. Plan it

| Run | What happens | What you do |
|---|---|---|
| `ideate` | Interviews you, then proposes both planning docs | **Push back on the scope cuts.** Its most useful act is telling you what it moved out of the first version. If it has a UI, give it any reference you already like — that fills the UI/UX section `prototype` starts from. |
| `architect` | **Six shape questions first** — separate services, background work, consistency, availability, load, external APIs — then structure, data model, where logic lives, and the quality bar as numbers | Expect "system design does not apply" for a small project; that is correct, not lazy. **Answer the six honestly** — they are what `stack` reads to rule technologies in and out, and they are cheap to say now and expensive later. **They are read together, not singly:** consistency across writes is a transaction requirement every relational database meets, while concurrent writers is the load question. |
| `stack` | Reads those answers and the quality bar, asks the platform, then whether you already know what to build with | Say if you do — it uses your choice and fills gaps around it. Versions get pinned. **It will say if your choice cannot meet the bar**; that is the point of the order. |
| `layout` | Takes the framework's own shape — directory names, where config lives, where tests go — and checks the ecosystem's traps | Approve it. It is markdown now and an installed framework with a lockfile after `scaffold`. |
| `scaffold` | Installs the whole stack into the layout just approved, then audits itself against the plan | Approve the command list. **Read the audit** — it reports anything missing rather than quietly succeeding. |
| `ci` | Writes one workflow file using the project's own verify command, runs it locally, **stops before pushing** | **Do this before the first item, not after the last.** One test and a typecheck is enough — the point is that the pipeline exists before the code does. |
| `context` | Generates the overview every session loads | Re-run it whenever a plan changes. |
| `prototype` | *Optional.* Throwaway mockups that settle the look, plus a durable `design.md` | Decide deliberately. Redoing HTML is free; redoing components is not. |

**The mockups are throwaway; the decisions are not.** `prototype` also writes
`blueprint/context/design.md` — the states, component conventions, and any
contrast value that was measured rather than chosen. `ship` deletes the mockups
and keeps that, so the next UI item builds against what was already settled
instead of reinventing it.

**Nothing is written without your approval** at `ideate`, `architect`, `stack`,
`layout`, or `scaffold`. Each stops and shows you the exact text or commands first.

## 3. Build it, one item at a time

```
spec → build → verify → review → ship
```

**`spec`** turns one plan item into a spec with small steps, each with an
observable *done when*. It **red-teams its own draft** before showing it to you
and leads with what the critique changed — that note is the point.

**`build`** works one step at a time: implements, shows the diff, explains it,
proves the done-when, then asks. Your options each time:

- **Continue** — straight to the next step
- **Commit checkpoint** — a cheap rollback point
- **Walk me through it** — line-level explanation, then asks again
- **Stop here** — the branch and ticked steps survive; `build` resumes from the
  first unchecked step

**If a step fails twice and nobody can say why, `build` stops and sends you to
`debug`.** That is deliberate: a third attempt made without understanding the
cause is a guess, and a guess that happens to go green is worse than the failure —
it retires the question while leaving the cause in place. `debug` reproduces and
isolates without touching product code, then hands the evidence back.

**`verify`** proves the spec against the running app. Its rule: **"could not
verify" is a valid result and never a pass.**

**`review`** audits the code and writes findings with durable IDs. An open P0 or
P1 blocks the merge.

**`ship`** archives the spec, makes one commit, squash-merges **with your explicit
approval**, then asks separately before pushing.

Repeat for the next item.

## 4. Take it live

| Run | When |
|---|---|
| `preflight` | Before the first release. `ci` already ran back in step 2. The whole-project go-live audit — **it can and should say no-go.** |
| `host` | Provision hosting, database, domain. **States the cost before creating anything.** |
| `deploy` | One environment at a time. Production needs its own explicit yes. |
| `monitor` | Error tracking and uptime, wired to the failure modes `architect` named |

**`AGENTS.md` gets an Environments table, starting at `scaffold`.** `development`
exists the moment there is code — not the moment something is hosted — and `ci`
adds itself, and `host` adds the rest much later. Each row says where its
configuration comes from and **whether it holds data anyone would miss**. That
last column is what `migrate` reads before it will touch a schema, and **anything
not in the table is treated as holding real data**, because an unrecorded
environment is an unknown one rather than a safe one.

**`architect` writes `blueprint/context/quality-bar.md`** — the performance number,
the scale this is actually built for, the security posture, what happens when it is
down. Short, and every line checkable. It is what lets `review` say *this misses
what the project promised* rather than only *this is an N+1*, and `preflight` check
the live thing against its own standard. **"One user, a few hundred rows, down until
I notice" is a real bar** — writing it down licenses simple choices instead of
leaving them looking careless.

**`preflight` is the one people skip.** It checks backups with a *tested* restore,
env vars set in the target, a rollback plan that has actually been tried, and a
README that is not scaffolder boilerplate. A project with faultless code and no
backups passes `review` and fails here — those are different questions.

## 5. Keep going

**Adding a feature later:** run `spec` again. If it is on the plan it takes the
next unchecked item; if it is new, it proposes the plan addition and stops for
approval before writing anything.

**Changing the database:** `migrate`. Schema first, code second, always separate
steps — so a code rollback never leaves the app talking to a schema it does not
understand.

**Something broken:** `debug` reproduces and isolates without editing product
code, then hands the evidence to `spec` or `build`.

**Learning from real use:** `monitor` is not only for outages. Run it deliberately
once a release has settled and ask what people actually use, where it hurts, what
they keep working around, and what it costs. **This is the only step where anything
from outside gets into the plan** — every other loop here runs between the plan and
the code, so a project can be perfectly executed against a plan nobody ever checked
against use. It proposes plan items and hands to `spec`, which owns the gate.
"Nothing worth acting on" is a real result.

**Telling people what changed:** `docs` writes `CHANGELOG.md`, derived from
`blueprint/history/` since the last released commit rather than from memory — which
is what stops the small fixes nobody remembers shipping from going unmentioned.
`deploy` points at it after a production release.

**Undoing a shipped feature:** `rollback` plans the reversal with a dependency
review first. **Undoing a bad release** is different — that is `deploy rollback`,
which restores the previous release now and investigates after.

**Checking everything still works:** `verify --all`. Ordinary `verify` proves one
item against the running app and then that proof is archived and never looked at
again — so a new item can break an old screen and the only thing that would catch
it is a test, which is precisely the kind of evidence `verify` exists because
tests do not give you. `--all` re-proves every shipped feature's done-whens from
the archive, separates regressions from claims that are merely superseded or
belong to a feature since cut, and raises what it finds in the findings ledger.
**It is the most expensive check here** and grows with the project — worth it
before a release or after a dependency upgrade, not every item. `preflight`
requires it, or an honest account of which claims the test suite genuinely covers.

**Changing what the project is for:** `ideate --rescope`. The plain `ideate` stops
when the plan is already filled, because the default path proposes a whole new
build plan and approving one erases the `- [x]` marks that are the entire resume
mechanism. The rescope mode runs the same interview but carries completed items
and their history across, names every item leaving the plan, and routes a checked
one to `rollback` — a shipped feature leaves code behind, and cutting the plan
line does not remove it. It hands off to `setup` and `context`, not `stack` and
`scaffold`, because there is already code here.

**Changing the stack after there is code:** there is no skill that does this, and
that is deliberate — it is a rewrite. `stack` refuses a project that has code and
sends you to `setup`, which *records* a stack rather than choosing one. So the
order is: make the change, then `setup` to re-read what the repo now is, then
`context` to regenerate the overview, and a `dev-notes/decisions.md` entry marking
the original choice superseded. **The cost of this is why `stack` asks what it
asks** — every question there is cheap before `scaffold` and expensive after.

**Changing the directory names after there is code:** that is `layout`, not
`stack` and not `architect`, and it is the cheapest of the three to change and
still not free — every config file the scaffolder generated points at paths.
**Tell the three apart by the question**: what the project is for is `ideate`,
how many things deploy is `architect`, what they are built with is `stack`, and
where the files sit is `layout`. Going to the wrong one gets a confident answer
to a question you did not ask.

## Checking where you are

Three skills, three different questions. **Picking the wrong one gives a
confident answer to a question you did not ask.**

| | Answers | Cost |
|---|---|---|
| `progress` | *Where am I, what is next?* Run it constantly. | seconds |
| `review` | *Is the code sound?* | minutes |
| `preflight` | *Can this face real users?* | longer |
| `prepare` | *Whose turn is it, what do I need to get?* | seconds |

`progress` does not read the code. `review full` is still not a launch check.
`prepare` is the only one that reports on **you** rather than the project - the
accounts, system software, hardware, manual checks and decisions no agent can do.
It reads `blueprint/context/needs-you.md`, which skills write the moment they hit
something they cannot do themselves, so the answer stops being rediscovered.

## Running unattended

`autopilot <from>..<to>` runs a range without stopping at each gate —
`autopilot spec..review` for one bounded pass, `autopilot stack..review` to carry
a planned idea to reviewed code.

**It is permanently blocked from anything git cannot undo:** provisioning,
production deploys, migrating real data, third-party accounts, pushing. If the
only way to undo a step is a backup, an invoice, or an apology, it does not run
unattended.

**Treat a long run as a draft.** It reviews its own work, which catches checkable
facts and is much weaker on a wrong assumption — the same assumption wrote both
the code and the review.

## If you only remember three things

1. **Read the diffs.** The comprehension gate is the entire point; everything
   else exists to make it possible.
2. **"Could not verify" is a real answer.** A fabricated pass is worse than no
   check, because it retires the question.
3. **`preflight` is allowed to say no.** A readiness check that always passes
   converts an unexamined risk into documented false assurance.
