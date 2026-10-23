# Story 028: CI fails on an ID that vanished without an alias, passes once it is aliased, and the old ID resolves through the alias

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Rule 2 "Renamed IDs are caught in CI"; Amendment 2026-10-23: the ID-manifest check accepts `--previous-manifest=<path>`)
**ADR Decision Summary**: The build keeps a generated, checked-in ID manifest (every current ID and its aliases). CI fails when an ID in the previous manifest is neither a current ID nor an alias of one, so a rename without an alias can never ship.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Use `JSON.stringify(data, "\t", true)` (sorted keys) so the manifest diff is stable. Keep the manifest outside `data/`: `ResourceLoader` can treat a `.json` file as a `JSON` resource, so it must not sit in a directory the catalog discovers.

**Control Manifest Rules (this layer)**:
- Required: "To rename, keep the record, change its `id` and add the old ID to its `aliases` (Rule 2)." Headless scripts call `ContentBootstrap.run()` from `_initialize()`.
- Forbidden: a hand-maintained manifest.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-28** GIVEN a previous ID manifest containing `char_old` and a current catalog where that record's `id` is `char_new` with no alias, WHEN the CI check runs, THEN it fails naming `char_old`. With `aliases: ["char_old"]` added, it passes. A save referencing `char_old` loads through the alias.

---

## Implementation Notes

*Derived from ADR-0001 Rule 2 and the Amendment 2026-10-23 (QA fixes applied: manifest path, format, script and argument pinned):*

- **Manifest.** Path `res://tools/ci/id-manifest.json`, checked in. Format: `{"format": 1, "ids": {"<live_id>": ["<alias>", ...], ...}}`, keys sorted, alias lists sorted.
- **Script.** `res://tools/ci/check-id-manifest.gd` (`extends SceneTree`), same shape as story 027: in `_initialize()`, read `--data-root=` (default `res://data`) and `--previous-manifest=` (default `res://tools/ci/id-manifest.json`), run `ContentBootstrap.run(catalog, data_root)`, and for every ID in the previous manifest (live IDs and aliases alike) check that it is a current live ID or a current alias. Print one line per vanished ID and exit `min(missing_count, 1)`. If the catalog itself is `FAILED`, print that and exit 1. `--write-manifest=<path>` writes a fresh manifest from the current catalog instead, which is how the checked-in file is regenerated.
- **CI.** Add a step to `.github/workflows/tests.yml` after story 027's step: check against the committed manifest. The regeneration after a deliberate content change is a developer step, documented in `tests/README.md`.
- **The "save loads" clause is simulated.** There is no Save/Load code yet. The third test proves the runtime path a save would take: `resolve_alias("char_old")` returns `char_new`, then `get_record(&"character", ...)` is non-null. **game-designer must confirm** this satisfies AC-28; otherwise that clause moves to the Save/Load epic and is recorded there. Flag it at `/story-readiness`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Save/Load & Settings: loading a real save file that names an aliased ID.
- Story 013: alias validity rules.

---

## Files

- `tools/ci/check-id-manifest.gd`
- `tools/ci/id-manifest.json` (generated from `res://data`)
- `.github/workflows/tests.yml` (ID-manifest step)
- `tests/integration/content_data/fixtures/id_manifest/previous-manifest.json` (contains `char_old`)
- `tests/integration/content_data/fixtures/id_manifest/renamed_no_alias/`, `.../renamed_with_alias/`
- `tests/integration/content_data/content_data_id_manifest_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied). The developer implements against these — do not invent new test cases during implementation.*

- **AC-28 / T1 no alias**: GIVEN `previous-manifest.json` with `char_old`, and `renamed_no_alias/` where the record's `id` is `char_new` with empty `aliases`, WHEN `check-id-manifest.gd` runs as a child process with both arguments, THEN the exit code is 1 and stdout contains `char_old`.
- **AC-28 / T2 alias added**: GIVEN `renamed_with_alias/` (same record, `aliases: ["char_old"]`), WHEN it runs, THEN the exit code is 0.
- **AC-28 / T3 runtime alias path (simulated save)**: GIVEN a catalog loaded from `renamed_with_alias/`, WHEN `resolve_alias("char_old")` is called, THEN it returns `"char_new"`, and `get_record(&"character", "char_new")` is non-null.
- Edge cases: `--write-manifest=` on `renamed_with_alias/` writes `{"format": 1, "ids": {"char_new": ["char_old"], ...}}` with sorted keys, and running it twice gives byte-identical files.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/content_data/content_data_id_manifest_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-012-resolve-alias.md`, `production/epics/content-catalog/story-027-headless-validate-content.md`
- Unlocks: None
