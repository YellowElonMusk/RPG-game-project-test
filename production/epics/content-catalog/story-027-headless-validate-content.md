# Story 027: The headless validation check exits 0 on valid data, and 1 with the full report on any error

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format ("Standalone headless validation"; Amendment 2026-10-23 "Headless exit code"); ADR-0004: Content Boot Ordering (§5)
**ADR Decision Summary**: `res://tools/ci/validate-content.gd` is a `SceneTree` script, run with `godot --headless -s`. It calls `ContentBootstrap.run()` from `_initialize()` (never `_init()`), gets the catalog with `root.get_node(^"ContentCatalog")`, prints the full report, and exits with `min(error_count, 1)`: 0 = valid, warnings allowed; 1 = any error. It accepts `--data-root=<path>`.
**ADR Version**: ADR-0001 2026-10-23; ADR-0004 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: The `_initialize()` vs `_init()` timing was verified on 4.7.2 (ADR-0004): the autoload does not exist yet in `_init()`, and its `_ready()` runs after `_initialize()` returns. User arguments after `--` are read with `OS.get_cmdline_user_args()`. A fresh checkout must run `godot --headless --path . --import` first, so the class cache exists.

**Control Manifest Rules (this layer)**:
- Required: "Headless validation script at `res://tools/ci/validate-content.gd`, exiting with `min(error_count, 1)` and accepting `--data-root=`." "Harness scenes and `validate-content.gd` call `ContentBootstrap.run()` in their own `_enter_tree()` / `_initialize()`, never `_init()`."
- Forbidden: calling `load_all()` directly from the script (it goes through `ContentBootstrap.run()`, so CI validates with every vocabulary and validator registered). Exiting with the raw error count (exit codes wrap past 255).
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-24** GIVEN the standalone headless validation check, WHEN run on valid data (warnings allowed), THEN it exits with code 0. WHEN run on data with any error, THEN it exits with code 1 and prints the full report.

---

## Implementation Notes

*Derived from ADR-0001 (Standalone headless validation; Amendment 2026-10-23) and ADR-0004 §5:*

- The path is settled: `res://tools/ci/validate-content.gd` (ADR-0001 and the control manifest agree). The exit-code conflict is settled too: `min(error_count, 1)`. ADR-0004 §5 and its diagram still say "exits with the error count". That wording predates the amendment; follow ADR-0001's amendment and the manifest.
- Script shape: `extends SceneTree`; in `_initialize()`, parse `--data-root=<path>` from `OS.get_cmdline_user_args()` (default `res://data`), get `root.get_node(^"ContentCatalog")`, call `ContentBootstrap.run(catalog, data_root)` (story 002's pass-through), print `ValidationReportText.build_log_text(catalog.report)` (story 024) to stdout, then `quit(min(error_count, 1))`.
- A missing or unreadable `--data-root` prints one line naming it and exits 1, never 0.
- **Test harness (settled).** A gdUnit4 integration test runs the script as a child process: `OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/ci/validate-content.gd", "--", "--data-root=<fixture>"], output, true)` and asserts on the returned exit code and the captured output.
- **CI wiring.** Add a step to `.github/workflows/tests.yml` that runs the script on the real `res://data`. How the workflow gets a Godot 4.7.2 binary outside the gdUnit4 action is devops-engineer's call; record the choice.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 028: the ID-manifest check.
- Story 029: the load benchmark.

---

## Files

- `tools/ci/validate-content.gd`
- `.github/workflows/tests.yml` (validate-content step)
- `tests/integration/content_data/fixtures/warnings_only/`, `.../two_errors/`
- `tests/integration/content_data/content_data_validate_cli_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS resolved: exit code `min(error_count, 1)`, `--data-root=`, harness pinned, stale path note removed). The developer implements against these — do not invent new test cases during implementation.*

- **AC-24 / T1 warnings only**: GIVEN `fixtures/warnings_only/` (valid, with at least one warning, e.g. story 019's `unreferenced` case), WHEN the script runs on it as a child process, THEN the exit code is 0 and stdout contains the warning entry's record_id.
- **AC-24 / T2 two errors**: GIVEN `fixtures/two_errors/` (two independent errors), WHEN the script runs on it, THEN the exit code is 1 (not 2) and stdout contains both entries' record_ids.
- Edge cases: `--data-root=res://does/not/exist` exits 1 with a line naming the path. A clean `valid_one_of_each` copy exits 0.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/content_data/content_data_validate_cli_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-020-mixed-severity-report.md`, `production/epics/content-catalog/story-024-error-screen-text.md` (`build_log_text`)
- Unlocks: `production/epics/content-catalog/story-028-id-manifest-ci.md`, `production/epics/content-catalog/story-029-load-benchmark.md`
