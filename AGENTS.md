## Checks

- Build and test: `ci_scripts/test.sh` (the same `xcodebuild` build-for-testing and test-without-building commands as `.github/workflows/ci.yml`; CI does not call the script itself). `--skip-ui` drops XCUITests, `--only ThinkTests/<Class>` narrows, `--build-only` compiles. Full logs land in `DerivedData/BuildLogs/`.
- Lint: `ci_scripts/lint.sh` checks Swift files changed against `origin/develop` with swift-format (`.swift-format`); CI does not run it yet, so run it before pushing. Fix a file with `xcrun swift-format format -i <file>`. The pre-commit hook runs it on staged files once `git config core.hooksPath .githooks` is set.

## Large files

`design/design-system.md` is about 47k characters. List its sections with `grep -n '^##' design/design-system.md` and read only the line range you need.

## Agent skills

### Issue tracker

Issues live in GitHub Issues on Vankata03/Think (`gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
