# Mobile Build Path

Taking a mobile app from an idea to reviewed code, and what differs from the web
path. Written after running the Expo scaffold for real — the warnings below are
things that actually happened, not things that might.

## Before you open a session

**For Expo, Node is the only prerequisite.** `npx` fetches `create-expo-app` on
demand, so there is nothing to install first.

**For Flutter or native, install the toolchain yourself first.** `scaffold`
checks for it and stops if it is missing — it will not install a multi-gigabyte
SDK on your machine, by design.

> **Check this first.** This machine runs **Node v20.18.1**, and `expo-doctor`
> wants `>=20.19.4`. Everything still installed and typechecked, but the doctor
> reports the runtime as unsupported. If you can upgrade Node before starting,
> do — it removes a warning you will otherwise see at every check.

**To verify anything on a screen you need a device.** Expo Go on your phone is
the cheapest route; a simulator needs Xcode or Android Studio. Without one,
`verify` can typecheck and run `expo-doctor` but must say plainly that nothing
rendered — that is an unverified result, not a pass.

## Start it

```bash
~/ai-project-starter/new-project.sh trail-log
cd trail-log
```

The command creates the directory with all 27 skills already inside, so when you
open the session everything is there. There is deliberately **no source
directory yet** — `scaffold` creates it once `layout` says where it goes.

## The sequence

```
ideate → architect → stack → layout → scaffold → ci → context
     → prototype → spec → build → verify → review → ship
```

1. **`ideate`** — interviews you into the two planning docs. Its most useful act is
   **cutting scope**: it will tell you which features it moved out of the first
   version and why. Push back if it cuts something you need.

2. **`architect`** — screens and navigation rather than routes. Names any device
   capability a feature actually needs (camera, location, notifications) and only
   those. Expect it to decline the system-design tier for a small app, which is
   correct.

   **It runs before `stack` because it decides how many deployable parts there
   are** — one application, or an app plus a separate backend of its own. A
   mobile app talking to its own API is a two-part project, and that is an
   architectural fact about the product, not a consequence of picking Expo.

3. **`stack`** — reads that shape and the quality bar, asks the platform, then
   **whether you already know what you want to build with**. If you say Expo,
   that is the decision and it fills in the gaps around it. If you want a
   recommendation, it gives one with a runner-up named. It also asks the
   **language** and settles **versions** — pin them.

4. **`layout`** — where the files physically sit, in the framework's own terms:
   Expo's `app/` router directory, where the theme lives, where tests are
   discovered from. Markdown now; an installed toolchain after the next step.

5. **`scaffold`** — installs the whole stack into that layout, not just the
   framework, then audits itself against the plan and reports anything missing.
   This is the step with the most mobile-specific behaviour; see below.

6. **`ci`** — writes one workflow file from the project's own verify command and
   runs it locally. **Do this before the first item, not after the last.** On
   mobile the pipeline is a typecheck and tests: a store build needs signing
   credentials, which belong in `deploy`, not here.

7. **`context`** — generates the overview every session loads. Re-run it whenever
   a plan changes.

8. **`prototype`** *(optional, but decide deliberately)* — settles the look in
   throwaway mockups before components exist. On mobile the tokens land in a
   **theme object or NativeWind config, not a stylesheet** — there is no CSS to
   port into.

9. **`spec` → `build` → `verify` → `review`** — one item at a time. `spec`
   red-teams its own draft before showing it to you; `build` works one reviewed
   step at a time; `review` writes findings that gate the merge.

10. **`ship`** — final safety pass, archive, one commit, squash-merge with your
   explicit approval. Asks separately before pushing.

## Where mobile differs

### The scaffolder fights for the same files

`create-expo-app` writes its own `AGENTS.md`, `CLAUDE.md`,
`.claude/settings.json` *and* initialises a `.git` — straight into paths the
workflow owns. `scaffold` handles this: it excludes the git directory, keeps your
files, and folds Expo's guidance into yours rather than discarding it.

> Expo's generated `AGENTS.md` says the SDK has changed and to read the versioned
> docs before writing any code. That is the framework itself warning that a
> model's training may be stale — which is why it gets kept verbatim rather than
> thrown away.

### The SDK version will not be the one you asked for

`create-expo-app` has no SDK flag. It always generates for its own current
release, so a plan naming SDK 54 produced **SDK 57**, with no error or warning.
`scaffold` surfaces that difference for you to settle — accept it and update the
plan, or pin afterwards.

### "Prove it runs" means something different

Expo declares no `engines` field, so package metadata cannot tell you whether the
runtime is compatible. **`expo-doctor` is the real check** — it caught the Node
version issue that metadata could not.

| Check | What it proves |
|---|---|
| `tsc --noEmit` | The code compiles |
| `expo-doctor` | The install is internally consistent — 21 checks |
| Simulator or device | The app actually renders. Nothing else does. |

### Shipping is not a deploy

`deploy` branches on what changed: an **over-the-air update** for JavaScript-only
changes, a **store build** when native code changed. Getting this wrong is quiet
— shipping a native change as an OTA update silently does nothing.

> **Store rollback is not immediate.** Submitting the previous build takes as
> long as review does, so the usual "roll back first, investigate after" rule
> does not hold once a build is in a store. Plan accordingly before you submit.

## What is proven, and what is not

**Run for real — the Expo scaffold path.** Full run on a throwaway project: the
merge kept every workflow file, typecheck passed, and `expo-doctor` reported 21
of 21 checks passing.

**Written, never run — everything after scaffold, on mobile.** The simulator path
in `verify`, the store submission path in `deploy`, and the mobile branch in `ci`
are written from knowledge of how these tools work, not from having run them
through this workflow. Expect to find gaps, and treat finding one as the point
rather than a failure.

**Blocked until the SDK is installed — Flutter, entirely.** The missing-toolchain
case is handled: `scaffold` stops and tells you what installing costs. The path
beyond that is unexercised.

## If you get stuck

Run `progress`. It reads the plan and git state in seconds and tells you where
you are, what drifted, and the single next action. It does not read the code —
that is `review` — and it says nothing about whether the app is fit to ship,
which is `preflight`.

---

*Written 1 September 2026, from running the Expo path on a throwaway project. If
something here contradicts what you see, the machine in front of you is right.*
