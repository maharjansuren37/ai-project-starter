---
name: verify
description: "Prove the current work actually does what its spec says, by running the real app and observing behavior against the done-when criteria in blueprint/context/current-work.md. Drives the app - browser, CLI, or server - captures evidence, and reports pass, fail, or could-not-verify per criterion. With --manual, writes a human walkthrough instead: what to start, where to go, what to click, what to expect, and what would count as wrong. Read-only either way: it observes and never edits source or commits. Use when the user runs `verify`, asks to confirm something works, wants proof before shipping, or asks how to test the change by hand."
---

# verify - prove it against the running app

Where this sits:

    `build` -> verify -> `review` -> `ship`

> **In a multi-part project**, two files live at the **product root**, not in
> this part: `blueprint/project-plan.md` (the product plan) and
> `blueprint/context/quality-bar.md` (the bar the whole product is held to -
> `architect` runs at the root and writes one there, not one per part).
> `AGENTS.md` records `Product root:` - read it from there rather than assuming
> a path. Everything else named here is this part's own.

`build` checks each step inline as it lands. This is the deeper gate for
when a done-when needs the *real running app* rather than a green build: a click
that triggers a download, a route that returns a file, a flow across screens.

A passing build proves the code compiles. This proves the thing the spec promised
actually happens.

## Before you start

- **`blueprint/context/current-work.md` holds no spec, or none of its steps are
  ticked** - there is nothing built to verify. Stop and say to run `build` first.
  Verifying an unbuilt spec produces a list of failures that describe the plan,
  not a defect.
- **A done-when names a number from `blueprint/context/quality-bar.md`** -
  measure it, do not assert it. "Under 500ms at p95" is proven with timings from a
  real run, and reporting it as met without them is a fabricated pass with a
  decimal point on it. If it cannot be measured here, that is could-not-verify.
- **The done-when criteria are not observable** - "works correctly", "is fast
  enough". Say so before running anything. This skill can only prove what someone
  wrote down as checkable, and a vague criterion is where a fabricated pass gets
  in.

## Input

| Argument | Mode |
|---|---|
| *(none)* | Prove every done-when in the current spec |
| a step, flow, or URL | Prove just that |
| `--manual` | Write a walkthrough for a person to follow, and run nothing |

`--manual` produces the guide someone uses to review the work themselves - before
approving a merge, or when they want to see it with their own eyes. It reads the
same spec and the project's real commands, then writes instructions. It proves
nothing on its own; it tells a person how to.

## Step 1 - build the checklist

Read `blueprint/context/current-work.md` and pull the observable *done when* criteria from its
build steps, plus any acceptance notes under Testing. Turn them into concrete
claims to prove - each one a specific observable behavior, never "it works".

If there is no current spec, check `blueprint/history/features` and
`blueprint/history/fixes` for the most recently archived work and say that is what
you are verifying. If there is nothing at all, ask what to verify rather than
guessing.

## Step 2 - get the app running

Use the project's real commands, from the Commands section of AGENTS.md.
Match the project type:

- **Web app** - start or reuse the dev server, then drive a real browser to the
  relevant routes. Prefer reusing a server that is already up over starting a
  duplicate on another port.

  **A served response is not a rendered page**, and this is the substitution to
  watch for. Fetching the HTML and finding the element in it proves the markup
  shipped, not that anyone can see it. **An element can be present, correctly
  labelled, reachable by keyboard, announced by a screen reader - and zero pixels
  tall.** That has happened here: an inline `<svg>` with a `viewBox` and no
  `width`/`height` has an intrinsic ratio but no intrinsic size, so `height: auto`
  resolved to nothing, and four passing verifications in a row all checked the
  markup.

  So for anything visual, **the evidence is an image, not a string match.** A
  screenshot from a browser is the standard. Where no browser is available, use
  whatever will rasterise the thing - an SVG renderer, a headless converter - and
  **look at the output**. Where nothing at all will render it, that is
  **could-not-verify, not a pass**, and the honest sentence is "I have not seen
  this."

  The mobile paths below already say this, because it was learned there first. It
  applies identically to the web.
- **CLI** - run the actual commands with representative inputs.
- **Server or API** - start it and hit the endpoints.
- **Library** - exercise the public API through an example or the test command.
- **Mobile app (Expo / React Native)** - start the dev server and open the app on
  a **simulator or a real device**. A bundler that starts proves nothing; the app
  has to render. Capture screenshots from the simulator. Where no device is
  available, run the typecheck and `expo-doctor`, then **say plainly that nothing
  has run on a device** - that is an unverified result, not a pass.
- **Mobile app (Flutter)** - `flutter run` against a simulator or device, with
  `flutter analyze` as the static floor. Same rule when no device is available.
- **Native mobile** - build and run from Xcode or Android Studio. This usually
  needs the user; say what to run and what to look for rather than claiming it.

**On mobile, "it built" is not "it works."** The gap between a green build and a
working screen is wider there than anywhere else - layout, permissions, platform
differences, and device size all break things a compiler never sees.

Use a browser automation tool only if the project already has one installed or
declared. Do not add one from this skill; if none is available, use another
real-browser path and say which you used.

## Step 3 - exercise each claim

Drive the app to each claim and capture evidence as you go:

- **Interact for real** - click, type, submit, download. Never assert from reading
  the code what the running app would have done.
- **Capture proof** - screenshots for visual claims, output for CLI and API
  claims.
- **Watch the console and the network.** A clean-looking screen with errors in the
  console is not a pass.

## Step 4 - report

One line per claim, with the evidence attached:

    [pass]  Download saves report-<slug>.pdf     file downloaded, opened, content correct
    [pass]  Both buttons show a loading state    screenshot: loading-state.png
    [fail]  PDF border missing                   printBackground not set; screenshot: pdf-no-border.png
    [skip]  Production render                    cannot verify locally - needs deploy

Then the bottom line: are all the done-whens proven, or not yet.

- **All proven** - say it is ready for `review`, then `ship`.
- **Anything failed** - hand back to `build` and name exactly what to fix. If the
  failure is one nobody can explain - the behavior contradicts the code, or the
  same criterion has now failed twice - route to `debug` first. `build` repairs a
  known cause; it is not where an unknown one gets found.
  Do not fix it here.
- **Anything unverifiable** - say so plainly and why. Never report it as a pass.

## Step 5 - the manual walkthrough (`--manual` only)

Instead of Steps 2-4, write a guide a person can follow with no further context:

1. **Start it** - the exact command, the URL, how to tell it is ready.
2. **Set up** - any account, seed data, or state needed first. Say how to get it.
3. **Walk the path** - numbered steps: where to go, what to click or type, what
   should happen at each point. One action per step.
4. **What good looks like** - the observable result for each done-when.
5. **What would count as wrong** - the specific failure modes worth watching for,
   including anything the automated checks cannot see.
6. **Gaps** - what this walkthrough cannot cover and why.

Write it for someone who has not read the spec.

**Every could-not-verify becomes a line in
`blueprint/context/needs-you.md`.** A criterion needing a screen reader, a
real device, or a person looking at the page is not a failure and is not a
pass - it is work waiting on a human, and unrecorded it reads as neither.
This is what stops "I have not seen this" from quietly becoming "this
works" by the time anyone reads the report.

## Rules

**Evidence, or it didn't happen.** Never report "passes", "works", or "verified"
without naming what proves it - the command and its output, the screenshot, the
response body. "I couldn't verify this" and "this failed" are useful, honest
results. A fabricated pass is worse than no check at all, because it retires the
question.

- **Observe, do not change.** This skill runs the app and reports. It never edits
  source, never commits, never merges. Fixing belongs to `build`.
- **Check the spec, not vibes.** Verify against the done-whens in
  `blueprint/context/current-work.md`, so "works" means what the spec said it would do.
- **Honest beats green.** "Could not verify" and "failed" are useful results. A
  faked pass defeats the gate and retires the question.

## Formatting

Match the conventions in `blueprint/context/ai-interaction.md` when it exists: short, scannable
markdown, lists for enumerations, a table when comparing options. Otherwise keep
it brief and direct by the same standard. Long prose blocks are the failure mode
to avoid - this output gets read while someone is mid-task.
