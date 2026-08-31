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
  `gui/CONTRIBUTING.md`, `../PRD.md` (lives one level up in the ralph
  harness, only present when running under ralph — skip if absent),
  `PROGRESS.md`, nearby tests, and the file being changed.
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

After a Linux-Docker → macOS round-trip, `npm install` regenerates a
Linux-flavoured `gui/package-lock.json`; revert it before committing Phase
work unless the lockfile change is deliberate.

## Commits

Use the F13 convention:

```text
<TYPE> [scope]: <description>
```

Six types — pick the most specific one that fits:

| TYPE | Meaning | Example |
|------|---------|---------|
| `ADD` | New file or new piece of functionality | `ADD [repo]: Dependabot config grouping tauri JS+Rust bumps` |
| `RM` | Removal of file / code / feature | `RM [gui]: drop unused locale stub from settings nav` |
| `NF` | New feature (functional, user-facing) | `NF [gui]: Phase 9 — i18n (en/de/fr/es) + zoom` |
| `BF` | Bug fix (use this for Dependabot too — dep bumps are fixes for "outdated transitive") | `BF [deps]: bump @sveltejs/kit 2.60.1 -> 2.61.0 (Dependabot #31)` |
| `RF` | Refactor (no behavior change) | `RF [ralph]: rename per-iteration heredoc target CLAUDE.md -> LOOP_CONTEXT.md` |
| `DOC` | Documentation, README, CHANGELOG, manifest, gitignore, comments | `DOC [docs]: append second-wave bumps to v0.4.1 CHANGELOG` |

Scope is lowercase: `[gui]`, `[shell]`, `[wizard]`, `[deps]`, `[ci]`,
`[docs]`, `[repo]`, `[ralph]`, etc. — name the area touched, not the
ticket / story number.

Keep the subject ≤ 72 characters. Put detail in the body.

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
the current `../PRD.md` (only present when running under ralph — skip if
absent) and `PROGRESS.md` flow.
