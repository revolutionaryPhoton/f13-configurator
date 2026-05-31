# AGENTS.md

This repository contains AI-assisted code. Treat this file as the shared
operating contract for Codex, Claude Code, and any future agent working in this
repo.

## Ground Rules

- Keep changes narrowly scoped to the requested task.
- Inspect existing patterns before editing code, tests, or docs.
- Preserve unrelated user changes. Do not revert, rewrite, or stage files that
  are outside the task.
- Do not reorganize large areas, rename concepts, or change public behavior
  unless explicitly asked.
- Never commit secrets, generated runtime state, local env files, logs, or build
  artifacts.

## Before Changing Code

- Read the relevant local context first: `README.md`, `SECURITY.md`,
  `gui/CONTRIBUTING.md`, `PRD.md`, `PROGRESS.md`, nearby tests, and the file
  being changed.
- Check `git status -sb` before editing.
- Prefer existing shell helpers, GUI patterns, test structure, and naming
  conventions over new abstractions.
- Add or update tests for behavior changes.

## Backpressure Before Commit

Before committing, report:

- files changed
- why the change is needed
- commands run and their results
- risks, skipped checks, or assumptions

Wait for explicit maintainer approval before committing unless the task clearly
asks for an autonomous commit.

## Required Checks

For shell/configurator changes:

```bash
shellcheck -S warning bin/* lib/*.sh
bats tests/
pre-commit run --all-files
```

For GUI changes:

```bash
cd gui
npm run check
npm run test:unit
cargo check --manifest-path src-tauri/Cargo.toml
pre-commit run --all-files
```

Do not run `npm run tauri dev` or `tauri build` inside automation loops unless
explicitly asked; those commands require a display or platform-specific GUI
runtime.

## Commits

Use the F13 convention:

```text
<TYPE> [scope]: <description>
```

Examples:

```text
NF [gui]: add settings import preview
FIX [shell]: quote generated path cleanup
DOC [deps]: bump svelte to 5.56.0
```

Keep the subject around 72 characters.

For AI-authored commits, end the commit body with the agent identity:

```text
Co-Authored-By: Claude Code
```

or:

```text
Co-Authored-By: Codex
```

## Pull Requests

- Prefer draft PRs unless the maintainer asks for ready-to-review.
- PR titles should follow the commit convention.
- PR bodies must include summary, validation, and risks.
- Do not merge PRs unless explicitly asked.
- For Dependabot PRs, verify checks, summarize impact, and merge one at a time
  only after approval.

## Ralph Loop

The Ralph loop is powerful and intentionally sharp. Do not relax sandboxing,
networking, mounted paths, or commit behavior without calling it out clearly.

Do not open per-story PRs from the Ralph loop unless explicitly asked. Follow
the current `PRD.md` and `PROGRESS.md` flow.
