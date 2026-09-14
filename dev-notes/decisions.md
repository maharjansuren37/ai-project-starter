# Decisions

Why this repo is shaped the way it is. Read this before changing its shape.

Entries are numbered permanently. A superseded decision is marked, never deleted.

## D1 - A new repo, not a rewrite of the pack this replaces (2026-08-31)

This grew out of an earlier private pack that worked and was well tested. It
covered idea through merged code, with a generator, a linter, and a
hash-manifest installer behind it.

Reviewing it turned up three things: the cold start was circular (`stack` told
you what to scaffold but was unreachable until after you had scaffolded), the
lifecycle stopped at merge, and the machinery had outgrown the job.

**Chose: a new repo, leaving that one untouched as reference.** The content here
is written fresh; the workflow design is carried over because it is good.

## D2 - Plain-name cross-references, so no generator is needed (2026-08-31)

The old pack templated `{{skill:build}}` into `/build`, `$build`, or `` `build` ``
per tool, needing a renderer, a partial system, a path registry, and a linter to
keep the adapters honest.

**Chose: write cross-references as plain names.** `` `build` `` reads correctly in
Claude Code, Codex, Cursor, and on paper. One `skills/` directory, fanned out to
both adapter trees by `cp`, so there is only ever one copy to edit.

**Cost:** no per-tool phrasing at all. Acceptable - the old pack's own adapters
were byte-identical anyway, and its tool-specific references caused a real bug
(stale `/status` after a rename, wrong for every tool but one, caught by nobody).

## D3 - The command creates the directory (2026-08-31)

The cold-start problem had two possible fixes: install skills globally into
`~/.claude/skills/` so they exist everywhere, or have the setup command create
the project directory itself.

**Chose: create the directory.** Project-based, nothing leaks into unrelated
projects, and there is never a moment with a tool open in an empty folder.

**Consequence:** the framework scaffolder can no longer run normally, since the
directory is not empty by the time a stack is chosen. `scaffold` handles that by
building into a temporary directory and moving the result in.

## D4 - No source directory is created up front (2026-08-31)

`create-next-app` makes `src/app/`, Flutter makes `lib/`, Expo makes `app/`.

**Chose: create none.** `scaffold` creates the source layout later, using the
framework's own convention, and records where it actually is in `AGENTS.md`. An
empty `src/` that Flutter ignores is clutter, and insisting on one means fighting
every framework's tooling and documentation.

## D5 - A thin update story (2026-08-31)

The old pack had a sha256 manifest, conflict detection, timestamped backups, and
atomic writes.

**Chose: `install.sh --force` re-copies skills; owned files are never touched.**
No manifest, no conflict detection, no backups.

**Cost:** a locally edited skill is overwritten by `--force` without warning. The
project is a git repo; that is what shows you the change. Revisit if this ever
actually costs someone work.

## D6 - autopilot is included, but gated (2026-08-31)

It was nearly dropped as too risky for a starter, especially with `deploy`,
`host`, and `migrate` now in scope.

**Chose: keep it, gated on complete information.** A hard preflight checklist,
and any miss stops the run before it begins. Its scope is the build loop only,
and its never-do list names every outward-facing skill explicitly.

## D7 - Standards are opt-in per project (2026-08-31)

The old pack's coding standards were OWASP-flavoured without naming OWASP, so
there was no external bar to check against - only judgment, restated.

**Chose: `setup` asks which standards apply and records them; `review` audits
against exactly what is recorded and names the source on each finding.** A
personal tool and a payment system need different bars, and imposing the stricter
one produces noise that trains people to ignore findings. Recording none is a
legitimate answer.

## D8 - Architecture before technology, and layout after both (2026-09-08)

The loop ran `ideate -> stack -> architect -> scaffold` for its whole life. The
justification was real: `architect`'s first decision was code layout, and a
layout turns on the language - React + Express shares a workspace, React +
ASP.NET shares nothing. So `stack` had to come first.

**That justification was about the wrong decision.** Code layout is a framework
convention, not architecture. The architectural questions - how many things
deploy, is there work outside a request, must data be consistent across more than
one write, whose failure is unacceptable - are the ones a technology should be
chosen *against*, and asking them second meant asking them once the answer was a
rewrite rather than a choice. Every real project built with this pack got a
single-file database because the stack question came first and nothing had yet
asked whether that was safe.

**Chose: split the two decisions and put them either side of `stack`.**
`architect` runs second and asks six shape questions and writes the quality bar
as numbers, before any technology exists to bias them. `stack` runs third and
reads both as inputs, saying which line of the bar each choice answers and
stopping if nothing in reach meets it. **`layout` is a new skill, the 27th**, and
runs fourth: it decides directory names in the framework's own terms, which is
knowable only once the framework is known and expensive once `scaffold` has
installed into it.

The rejected alternative was folding layout into `scaffold`. It fails on
approval: `scaffold` runs a long list of install commands, and a layout decided
inside it is one nobody was asked about before a lockfile existed.

This moved nine documented claims that were individually true and collectively a
loop that no longer exists. `tests/test-seams.sh` now asserts no file attributes
the directory layout to `architect`, and pins the handoff pairs to the new order.
