# Coverage - what has actually been run

**Which skills have been exercised against real code, on what, and what is still
unproven.** The chronological record of those runs is a local working diary and
is not published, so answering "has `rollback` ever run?" from it meant reading
thousands of lines and reconstructing the answer.

That reconstruction was got wrong three times in one file: the open items said
**13 skills unrun** in one bullet and **23** in another while the header said
**every skill has run**, and a later pass listed `autopilot` as never run when it
had been. This table exists so the question has one answer.

**Update it in the same change as the run**, not afterwards. A coverage table
that lags is worse than none, because it is believed.

Legend: **yes** - run against real code and the result checked · **partial** -
run, but a named part of it never exercised · **no** - never run in a real
conversation.

## The projects

Real projects, named here by what they are rather than what they are called.

| | what it is | what it was for |
|---|---|---|
| cli | TypeScript CLI, 4 items, 35 tests | the whole plan-and-build loop, `ci`, `debug`, `host` stopping |
| static-site | vanilla HTML/CSS/JS, one screen | `prototype`, and the first real `host` + `deploy` - live on a VPS |
| static-app | vanilla web, 4 items, 21 tests | full loop to production; replaced static-site at the same domain |
| library | TypeScript library | `stack`'s library branch and `scaffold` with no scaffolder |
| two-part-api | TS API + PostgreSQL, static web client, **two parts** | `architect`'s two-part path, `migrate`, `integrate`, `contracts/` |
| brownfield-nextjs | an existing Next.js + Prisma project, not built here | `preflight` against something it should fail |
| django-phone | Django 5.2 + SQLite, phone-first web app | **the first non-JavaScript project** - `architect`, `scaffold` and `setup` against a Python ecosystem |
| react-dotnet | React 19 + **ASP.NET Core 10** on SQLite, **two parts**, contract by OpenAPI codegen | **the two-ecosystem path** — `architect`'s React+ASP.NET branch, `convert-to-parts.sh` on a planned project, `integrate`'s contract check across two languages |
| throwaways | Vite, Expo, Flutter, one autopilot run | `scaffold` per stack; `autopilot stack..review` |
| django-loop | Django 6.1 + SQLite web app, skill-mastery tracker | **the whole loop on the current pack** - `ideate` through `ship`, item 1 merged, CI green. The first end-to-end run since the day's fixes |
| three-part-scratch | 3-part scratch product (web, api, worker) | **the coordination mechanisms** - deadlock, freeze gate, review cap; found the board naming parts that do not exist |
| two-part-autopilot | a real two-part product | **a full unattended `autopilot` run** across parts |
| expo-workspace | an existing npm workspace - two Expo apps, a Next.js web app, an Express API and a shared library; the code came before the workflow | **the brownfield route on a multi-part repository** - `install.sh` and `setup`, adopted as a single-part install at the root; later `progress` |
| nextjs-app | Next.js 16 + PostgreSQL 18 + Drizzle, recipe and meal planning | **the reordered loop end to end in one project** - `ideate` to a merged, reviewed, documented item |

## Plan

| skill | run | where | what it proved, or found |
|---|---|---|---|
| `ideate` | yes | cli, static-app, django-loop, nextjs-app | **2026-09-07: interviewed a real user for the first time.** The owner's answers changed the project twice - a CLI became a web app when sync surfaced, and "track or help?" was a fork I could not resolve for them. **Step 2's scope-cutting earned its keep**; the `--rescope` mode is still unexercised. **2026-09-08 on nextjs-app:** the scope cut earned its keep again - the owner picked every option and four were moved out, two with reasons that stuck |
| `architect` | yes | cli, two-part-api, react-dotnet, django-loop, nextjs-app | Two-part decision for a real reason. **react-dotnet: its layout options were JS-shaped** — "flat" breaks .NET. **That finding split `layout` out and moved this skill ahead of `stack`** (D8). **First run in the new order 2026-09-08 on nextjs-app**: the six questions produced three yeses that were all the same dependency, which is the result that stops a queue being invented. Two defects — the third question's stated consequence was **factually wrong** (transactions, not storage engines), and nothing said what heading level Step 3's output uses, so it broke the plan's numbered structure |
| `stack` | yes | cli, library, react-dotnet, django-loop, nextjs-app | **Had no CLI option**; now 7 platforms. **react-dotnet: it never checks a version against the installed runtime**. **First run in the new order 2026-09-08**: the bar-check worked as designed and **eliminated a client-rendered SPA on a requirement rather than on taste** — an SPA has no server-side page render, so the 400ms line is meaningless against it. Two defects — Step 1 still interviewed for the bar `architect` had already written, and **nothing reconciled the data model against a library that owns part of it** (Better Auth vs a hand-written `User`), a seam the reorder itself created |
| `layout` | yes | nextjs-app | **First run 2026-09-08.** Step 3's trap check earned the skill: `node --test` does not resolve tsconfig path aliases, so colocating tests beside their subject was **forced, not preferred** - a separate `tests/` tree would have made every import `../../src/...`. Also found that node executes every file inside any directory named `test`. **Half-verified its own decision**: it checked the test runner and not the typechecker, and `scaffold` then hit `allowImportingTsExtensions` |
| `scaffold` | yes | Vite, Expo, cli, library, django-loop, nextjs-app | 4 gaps: engine check, exit codes lie, agent files, no-scaffolder path. **2026-09-08 on nextjs-app:** caught `--agents-md` defaulting on in create-next-app, which would have overwritten the workflow's own entry point. Its `preflight` findings later became the production-shaping fixes to this skill |
| `ci` | yes | cli, brownfield-nextjs, django-loop, nextjs-app | **Pipeline executed on a real runner and passed** (2026-09-06, 1m12s). **2026-09-08 on nextjs-app:** the verify command passed locally and **failed on a clean checkout** - gitignored route types - which is now a rule here |
| `context` | yes | cli, static-app, django-loop, nextjs-app | -. **2026-09-08 on nextjs-app:** found three plan contradictions, including a hand-written `User` table the chosen auth library owns |
| `prototype` | yes | static-site | **5 of 10 contrast values were wrong** until measured |

## Build

| skill | run | where | what it proved, or found |
|---|---|---|---|
| `spec` | yes | cli, static-site, static-app, django-loop, nextjs-app | Planned items and the ad-hoc fix mode. **2026-09-08 on nextjs-app:** Step 4's red-team found a broken step order that would have redirected to a route built one step later. **`--preview` still never run** |
| `build` | yes | all, django-loop, nextjs-app | Done-when check and the two-failure stop both fired. **2026-09-08 on nextjs-app:** five steps, each proven at its own done-when. Surfaced that per-step approval is oversold - it earns its keep on step 1 and is ceremony by step 3 |
| `verify` | yes | all, django-loop, nextjs-app | `--manual` run once on static-site. **Never run on a simulator or device.** 2026-09-08 on nextjs-app: 5/5 done-whens, the quality-bar number **measured rather than asserted**. **`--all` still never run**, and reviewing it found it would read the archive directory's own README as an archive |
| `review` | yes | all, django-loop, nextjs-app | Found defects the spec red-team missed, twice. **2026-09-08 on nextjs-app:** nine findings, none blocking. Measured a 20,000-row write on an unauthenticated endpoint rather than asserting it |
| `ship` | yes | cli, static-site, static-app, django-loop, nextjs-app | Feature and fix archives; open P2/P3 carried across merges. **Push never run**. **2026-09-08 on nextjs-app:** its safety pass caught pack skill files committed onto a feature branch - a squash-merge would have folded a pack update into the item and regressed two skills |
| `debug` | yes | cli | Routed to correctly after two failures. **I wrote the bug, so it could not surprise me** |

## Operate

| skill | run | where | what it proved, or found |
|---|---|---|---|
| `preflight` | yes | brownfield-nextjs, static-app, nextjs-app | Returned **no-go** as predicted; found 3 gaps in itself. **2026-09-08 on nextjs-app:** correct NO-GO. Found three things that were cheap at `scaffold` and retrofits by then, which became the `scaffold` fixes |
| `host` | partial | cli (stopped), static-site VPS, **django-loop** | **Only the self-managed shape.** Managed, container, static-host and serverless rows are written from knowledge |
| `deploy` | partial | static-site, static-app, **django-loop** | Self-managed only. Rollback tested both directions (~700ms) |
| `monitor` | yes | static-site, local rig | 3 checks on a timer. **2026-09-07: delivery closed** - a webhook channel stood up, service killed, and the alert message proven to arrive and be recorded. Detection-without-delivery is no longer the gap |
| `migrate` | yes | two-part-api | Against real rows; the naive `ADD COLUMN NOT NULL` failed exactly as written |
| `docs` | yes | static-app, nextjs-app | Wrote the changelog from the archive. **2026-09-08 on nextjs-app:** replaced a template README that `preflight` blocked on, and caught two decisions the code carried with nothing explaining them |
| `rollback` | yes | brownfield-nextjs | **Ran 2026-09-06.** Five defects, incl. Step 2 stopping where Step 3 must write - its deliverable was unreachable for the case it exists for |

## Multi-part

| skill | run | where | what it proved, or found |
|---|---|---|---|
| `integrate` | yes | two-part-api, react-dotnet | Caught contract drift both parts' own checks passed on — now proven **across two ecosystems**, C# to TypeScript |
| `orchestrate` | partial | two-part-api, three-part-scratch, two-part-autopilot | Contract line on two-part-api. **2026-09-07: deadlock detection, the freeze gate and the review cap all fired for the first time** against constructed board state on three-part-scratch. Step 1's drift check caught status files claiming items no build plan held. **Still unproven with two live sessions**: I wrote the board I then read, so nothing could surprise me |

## Not on the linear path

| skill | run | where | what it proved, or found |
|---|---|---|---|
| `autopilot` | yes | a throwaway, three-part-scratch, two-part-autopilot, nextjs-app | One range on a throwaway; found the empty-diff bug. **2026-09-07: a full unattended `spec..review` over a real two-part product** - preflight enforced, part claimed on the board, branch and 4 checkpoint commits, 7 tests, done-whens re-run by hand, 3 findings with IDs, review packet, board left `waiting`, and the cap then refusing the next run at depth 2. **Found the circular branch precondition** that made its own headline usage unreachable. **2026-09-08 on nextjs-app:** ran `build..review` - a range that was illegal until that run showed `build` had to be a legal start |
| `setup` | yes | brownfield-nextjs, expo-workspace | **Ran 2026-09-06.** Found `ci` unreachable on the brownfield route, and that template files froze at install time forever. **2026-09-11 on expo-workspace:** a code-first npm workspace adopted single-part. Backfilled coding standards and a quality bar from the code - most bar rows honestly left unmeasured - recorded four contradictions in the existing docs as UNDECIDED rather than resolving them by guess, and opened 14 `needs-you.md` lines, 2 blocking. Its report named `context` then `ci`, because **Step 5 named `ci` as the next skill, Step 7 named only `context`, and the skill's own chain puts `ci` first** - the file disagreed with itself about what comes next. **Fixed 2026-09-15**: Step 7 now names every remaining step in the chain's order, with a seams test proven to fail on the old text |
| `progress` | yes | brownfield-nextjs, nextjs-app, expo-workspace | **Ran 2026-09-06.** Four defects: template residue, an mtime freshness check a hand edit defeats, an invalid archive count, no finished-plan state. **2026-09-08 on nextjs-app:** caught an overview stale *in content* while its timestamp looked fine, and product code committed to `main` with no spec. **2026-09-14 on expo-workspace:** caught that `context` and `ci` never ran after `setup` - `setup`'s report had named both, and the session's closing summary after a push dropped them. Recovering a handoff a conversation lost is what this skill is for |
| `prepare` | yes | brownfield-nextjs, nextjs-app | **Ran 2026-09-06.** Four defects, incl. reporting "nothing is blocking" when a user-owned file was broken. **2026-09-08 on nextjs-app:** found an empty `BETTER_AUTH_SECRET` that stops the very next item, and a hostname nobody had ever chosen - neither recorded anywhere |

## The honest summary

**All 27 run.** Three only partly - `host`, `deploy`, `orchestrate`. **Every
skill in the plan-and-build loop has run against one project** - nextjs-app,
taken from `ideate` to a merged, reviewed, documented item under the reordered
loop. That is the first time the whole loop has been exercised end to end in one
project rather than assembled from several.

**The reordered plan phase found six defects in one pass** - roughly the usual
rate for first contact, and none of them visible to any structural check. Two are
worth repeating because of where they came from: the third shape question
**stated something untrue** about what its answer settles, and **nothing
reconciled the data model against a library that owns part of it**. The second is
a seam the reorder created: the model is now written before the stack, so a
library chosen later can own tables the plan already described.

**What is left is not a list of skills. It is resources**, and that distinction
is the one `prepare` was built to make: most of these are things only a person
can supply, and no amount of work on the pack closes them. Listed in the order
they would hurt:

1. ~~**CI has never executed anywhere.**~~ **Closed 2026-09-06** - a pipeline
   `ci` generated ran on GitHub Actions and passed in 1m12s. It is the one item
   on this list that was closed by getting a resource: a repository with a
   remote.
2. ~~**Monitoring alerts have no delivery channel.**~~ **Closed 2026-09-07** - a
   webhook channel, a killed service, and one alert message proven to arrive.
   The channel was local, which proves the wiring and not a hosted provider.
3. **Every hosting shape but self-managed.** Managed platform, container, static
   host and serverless are written from knowledge, not use. **Static host was
   set up and then deliberately skipped (2026-09-07)** - the page, a health
   endpoint and a commit-stamping Pages pipeline were built and ready, and the
   run was dropped rather than publish a throwaway public repo to close one
   table row. A decision, not a gap nobody got to. **Container is the same
   shape**: adding the user to the `docker` group is a root-equivalent privilege
   change to test a row that changes nothing shipped.
4. **The multi-part coordination mechanisms.** ~~Never fired.~~ **Fired
   2026-09-07** - deadlock, freeze gate and the cap, plus a measured proof that
   separate status files survive 600 concurrent writes where the rejected shared
   table is truncated to empty. What is still missing is two *agent sessions* at
   once, not two writers.
5. **Mobile.** Nothing has run on a simulator or a device.
6. **The interviews.** `ideate` and `stack` have never faced someone whose
   answers I did not already know.

**The two-ecosystem path is no longer written-from-knowledge.** react-dotnet
(2026-09-06) built React + ASP.NET Core end to end: `convert-to-parts.sh` on a
planned project, a build-time OpenAPI contract, a generated TypeScript client,
one `make verify` across both, and `integrate` catching a C#-to-TypeScript
rename. It found six defects. What it did **not** cover: `orchestrate` with two
sessions at once, and anything rendered — no browser existed on that machine.

**None of this is visible to `check.sh` or `tests/run.sh`.** Both check that the
pack is internally consistent. Whether a skill behaves well when an agent follows
it is answered only by running it against something real.
