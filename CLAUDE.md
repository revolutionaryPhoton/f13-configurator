# CLAUDE.md

This repository's operating contract for AI agents — coding rules, commit
convention, backpressure checks, scope discipline, and ralph-loop
guard-rails — lives in [`AGENTS.md`](AGENTS.md).

**Read [`AGENTS.md`](AGENTS.md) first.** It applies to every agent
working in this repo (Claude Code, Codex, anything future).

## Per-iteration loop state

When this repo is running under the
[ralph loop](https://github.com/revolutionaryPhoton/f13-configurator-ralph),
`ralph.sh` writes a `LOOP_CONTEXT.md` file into the working directory
on first run. It carries the dynamic per-iteration state that
`AGENTS.md` deliberately doesn't capture:

- The current loop target (active phase, active stories)
- Stories currently fenced as out-of-scope
- The exact backpressure commands for this iteration

`LOOP_CONTEXT.md` is `.gitignore`d on purpose. If it exists locally,
read it **after** `AGENTS.md` — it overrides nothing, just adds the
"what to work on right now" layer. If `LOOP_CONTEXT.md`'s backpressure
commands differ from `AGENTS.md`'s Required Checks, run the **union**
of both.

## Loop harness

The [GitHub ralph-loop project](https://github.com/revolutionaryPhoton/f13-configurator-ralph)
is the canonical loop implementation. Its local checkout (`../ralph.sh`,
`../OPERATIONS.md`) is a **host-side** reference only.

It is deliberately **not** visible from inside the loop sandbox: docker
mode mounts exactly this repo (`/workspace`), `PRD.md` (`/PRD.md`) and the
prompt — the harness, `.env.local` and `~/.claude` are all excluded on
purpose. If you are running as the loop agent, do not go looking for them;
see the ralph repo's `SECURITY.md` for why.

## Source-of-truth files

- [`AGENTS.md`](AGENTS.md) — operating contract
- `../PRD.md` — product requirements, story catalogue; lives one level
  up in the ralph harness and is only present when running under
  ralph. If it's absent, skip it.
- [`PROGRESS.md`](PROGRESS.md) — story tracker, pending-stories table
- [`README.md`](README.md) — user-facing project overview
- [`SECURITY.md`](SECURITY.md) — security posture + AI-generated disclosure
- `LOOP_CONTEXT.md` (local only) — current iteration state when under ralph
