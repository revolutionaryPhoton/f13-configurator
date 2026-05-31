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
"what to work on right now" layer.

## Source-of-truth files

- [`AGENTS.md`](AGENTS.md) — operating contract
- [`PRD.md`](PRD.md) — product requirements, story catalogue
- [`PROGRESS.md`](PROGRESS.md) — story tracker, pending-stories table
- [`README.md`](README.md) — user-facing project overview
- [`SECURITY.md`](SECURITY.md) — security posture + AI-generated disclosure
- `LOOP_CONTEXT.md` (local only) — current iteration state when under ralph
