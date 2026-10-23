# Story 001: Install gdUnit4 and prove the runner discovers and passes one test

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md` (Acceptance Criteria preamble: "[L] Logic (automated gdUnit4 test under `tests/unit/content_data/`)")
**Requirement**: None directly. This is the infrastructure prerequisite named in `production/epics/content-catalog/EPIC.md` ("Story 1 is test setup... It blocks every Logic story in all four Foundation epics"). It unblocks TR-content-001 to TR-content-012.
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: None (infrastructure only)
**ADR Decision Summary**: N/A. The test runner command comes from `project.yaml` `commands.test` and `.claude/docs/coding-standards.md` (CI/CD Rules).
**ADR Version**: N/A

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Godot 4.7 replaced the Asset Library with the **Asset Store** (`docs/engine-reference/godot/VERSION.md`, 4.7 row). The gdUnit4 release installed must support 4.7.2; confirm it in the editor before committing it.

**Control Manifest Rules (this layer)**:
- Required: none specific. Infrastructure predates every Foundation rule.
- Forbidden: none specific.
- Guardrail: CI rule from coding-standards: "Never disable or skip failing tests to make CI pass."

---

## Acceptance Criteria

*Infrastructure criterion (no GDD AC; from EPIC.md and the QL-STORY-READY gate):*

- [ ] With gdUnit4 installed at `res://addons/gdUnit4/` and its version recorded, running `commands.test` (`godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode`) discovers exactly 1 test, reports it passed, and exits 0.

---

## Implementation Notes

*Derived from `tests/README.md` (scaffolded by `/test-setup` on 2026-10-22) and the QA gate:*

- **`/test-setup` has already run.** `tests/README.md`, `tests/unit/`, `tests/integration/`, `tests/smoke/critical-paths.md` and `.github/workflows/tests.yml` exist. Do not re-scaffold them. What is missing is gdUnit4 itself: the repo has no `addons/` directory.
- **Install gdUnit4 through the Godot 4.7 Asset Store** (editor → Asset Store → "GdUnit4"), then enable it under Project → Project Settings → Plugins and restart the editor. **This step may need the user**: the Asset Store is an editor UI flow, and a headless agent may not be able to complete it. If so, stop and ask the user to install it, then continue. A pinned release archive from the gdUnit4 GitHub releases page, unpacked into `addons/gdUnit4/`, is an acceptable fallback if the Asset Store listing lags 4.7.2.
- **Pin and record the version.** Write the installed gdUnit4 version (from `addons/gdUnit4/plugin.cfg`) into `tests/README.md` under "Installing GdUnit4", and into this story's Files/Completion notes. Commit `addons/gdUnit4/`. The CI workflow already uses `version: 'installed'`, so CI runs the committed copy.
- **Verify the CLI path exists**: `res://addons/gdUnit4/bin/GdUnitCmdTool.gd` (capital U).
- **Write one trivial test** at `tests/unit/content_data/content_data_framework_smoke_test.gd` (`extends GdUnitTestSuite`, one function `test_framework_runs_passes()` asserting `assert_bool(true).is_true()`). It also creates the `tests/unit/content_data/` directory that every later story uses. Create `tests/integration/content_data/` too (an empty directory needs a `.gdkeep` file to be committed).
- **Why one real test.** An exit code of 0 with zero tests discovered is the "0 tests, Passed" false pass that `.claude/docs/directory-structure.md` warns about. The pass condition is therefore "1 discovered, 1 passed, exit 0", read from the runner's summary output, not from the exit code alone.
- Test naming follows `.claude/rules/test-standards.md`: file `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`. The system name for this epic is `content_data`, matching the GDD's test root.
- The validate-content script path is settled: `res://tools/ci/validate-content.gd` (ADR-0001 and control manifest agree). It is built in story 027, not here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the first real catalog tests and fixtures.
- Story 027: `tools/ci/validate-content.gd` and its CI step.
- Changes to `.github/workflows/tests.yml` beyond what the installed addon needs (none expected).

---

## Files

- `addons/gdUnit4/` (installed, committed)
- `project.godot` (plugin enabled)
- `tests/README.md` (pinned gdUnit4 version recorded)
- `tests/unit/content_data/content_data_framework_smoke_test.gd`
- `tests/integration/content_data/.gdkeep`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: The runner discovers and passes exactly one test.
  - Setup: gdUnit4 installed and enabled; `tests/unit/content_data/content_data_framework_smoke_test.gd` present; no other test files in `tests/`.
  - Verify: run `commands.test` from the project root and read the summary.
  - Pass condition: the summary reports 1 test discovered and 1 passed, 0 failures, 0 orphans, and the process exits 0. The gdUnit4 version is written in `tests/README.md`. A run reporting "0 tests" is a **fail**, whatever the exit code.
  - Edge cases: run it after `godot --headless --path . --import` on a fresh checkout, so the class cache exists.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-*.md`), recording the runner summary ("1 discovered, 1 passed"), the exit code and the pinned gdUnit4 version. Gate level: ADVISORY. The smoke test file itself must also exist.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/content-catalog/story-002-load-one-of-each-type.md` (and through it every later story in this epic)
