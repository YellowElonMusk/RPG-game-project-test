# Story 024: Build the capped error-screen text and the full log text from a 30-error report

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (report format pinned in GDD F3/F4)
**ADR Decision Summary**: This epic defines the error-report data format; the Content Error *scene* belongs to `game-state-scene-flow`. F4: `displayed_error_count = min(error_count, ERROR_SCREEN_CAP)`, with `ERROR_SCREEN_CAP` a project-config knob (10–50, default 20). The log always holds the full report.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none. Pure string building, no scene tree.

**Control Manifest Rules (this layer)**:
- Required: "Validation entries are structured...; error screen lists the first `ERROR_SCREEN_CAP`; log holds all" (TR-content-008). Coding standard: "Gameplay values must be data-driven (external config), never hardcoded."
- Forbidden: translating validation errors or the Content Error screen (ADR-0013 Implementation Guidelines: "Logs, IDs, validation errors and the Content Error screen must not be translated").
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-21** GIVEN 30 errors and the default `ERROR_SCREEN_CAP` of 20, WHEN the error-screen text is built, THEN it contains exactly the first 20 errors in report order and the log file path, and the log contains all 30.

---

## Implementation Notes

*Derived from GDD F4, UI Requirements and Tuning Knobs:*

- Add `src/data/validation_report_text.gd` (`class_name ValidationReportText`, static, pure):
  - `static func build_error_screen_text(report: Array[Dictionary], cap: int, log_path: String) -> String`: the first `min(error_count, cap)` **error** entries in report order, one per line, each with record ID, field and location (GDD UI Requirements), then a final line with the full log path.
  - `static func build_log_text(report: Array[Dictionary]) -> String`: every entry (errors and warnings) in report order, one per line.
- **Config.** `ERROR_SCREEN_CAP` is read from project config, never written as `20` in the builder. Add a small config resource, `ContentReportConfig` (`src/data/content_report_config.gd`, `@export var error_screen_cap: int = 20`, clamped to 10–50) with `static func load_or_default()` reading `res://data/config/content_report_config.tres`, following the `StatsConfig.load_or_default()` pattern (ADR-0007). `data/config/` is outside the catalog's type directories (story 002), so it is never loaded as content. Record the path in the Completion Notes.
- The builder takes the cap and log path as arguments (dependency injection), so the unit test never reads config or the filesystem.
- Writing the log file to disk, and choosing its path, happen at the call site (the Content Error mode in `game-state-scene-flow`, or `validate-content.gd` in story 027), not here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 025: the scene that shows this text (`game-state-scene-flow`).
- Story 027: printing the full report in the headless check.

---

## Files

- `src/data/validation_report_text.gd`
- `src/data/content_report_config.gd`
- `data/config/content_report_config.tres` (default 20)
- `tests/unit/content_data/content_data_report_text_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-21 / T1**: The screen text holds exactly the first 20 errors and the log path.
  - Given: 30 synthetic error entries, built by a factory function in the test file, with **zero-padded** record_ids `char_err_01`…`char_err_30` in report order, an injected cap of 20 and an injected log path.
  - When: `build_error_screen_text(report, 20, path)` is called.
  - Then:
    - ids 01–20 each appear once, in report order
    - ids 21–30 are absent
    - the log path string appears after the last entry
- **AC-21 / T2**: The log holds all 30.
  - When: `build_log_text(report)` is called.
  - Then: all 30 ids appear, in order.
- **Config default**: a separate one-line test asserts that `ContentReportConfig.load_or_default().error_screen_cap == 20`.
- Edge cases: zero padding is load-bearing, because `char_err_1` is a substring of `char_err_10`. With 5 errors and cap 20, all 5 are listed. Warnings in the report are not counted toward the cap and are not shown on the screen.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_report_text_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-023-deterministic-report-order.md`
- Unlocks: `production/epics/content-catalog/story-025-error-screen-on-launch.md`, `production/epics/content-catalog/story-027-headless-validate-content.md`
