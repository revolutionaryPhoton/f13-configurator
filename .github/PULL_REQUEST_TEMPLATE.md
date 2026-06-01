<!--
Title should follow the F13 commit convention:
  <TYPE> [scope]: <description>   (≤ 72 chars)
  TYPE ∈ ADD | RM | NF | BF | RF | DOC   scope e.g. [gui] [shell] [release] [docs]
See .github/CONTRIBUTING.md for the full guide.
-->

## Summary

<!-- What does this change and why? One or two sentences. -->

## Related issue

<!-- e.g. Closes #123 — link the user-story / bug it addresses, if any. -->

## Surface

- [ ] Desktop GUI (`gui/`)
- [ ] Shell wizard (`bin/` + `lib/`)
- [ ] Release / packaging
- [ ] Docs / project meta

## Test plan

<!-- How did you verify this? Commands run + what you observed. -->

## Backpressure

<!-- Tick what applies to the surfaces you touched. Both must pass for code changes. -->

- [ ] **Shell** — `shellcheck -S warning bin/* lib/*.sh` && `bats tests/`
- [ ] **GUI** — `cd gui && npm run check && npm run test:unit && cargo check --manifest-path src-tauri/Cargo.toml`
- [ ] New `.sh` ships with a bats test / new `.svelte`/`.ts` ships with a vitest test
- [ ] N/A — docs/meta only

## Checklist

- [ ] Title follows `<TYPE> [scope]: <description>` (≤ 72 chars)
- [ ] No secrets, generated state, local env files, or build artifacts committed
- [ ] `CHANGELOG.md` updated if this is user-facing
- [ ] If an AI agent wrote/co-authored the work, the commit body ends with `Co-Authored-By: Claude Code` (or `Codex`) — and only then
