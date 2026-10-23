# Story 020: Two errors and two warnings fail the catalog, and the report carries all four with the right severities

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (F3)
**ADR Decision Summary**: `validation_outcome = Failed if error_count > 0, else Ready`. Worked example: 2 errors and 2 warnings give Failed, with all 4 entries in the report.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**:
- Required: "Validation runs over the complete record set before reporting, every problem collected."
- Forbidden: "Never fail fast on the first bad record"; suppressing warnings once an error exists.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-19** GIVEN a fixture with 2 errors and 2 warnings, WHEN validating, THEN the state is Failed and the report contains all 4 entries with the correct severities.

---

## Implementation Notes

*Derived from GDD F3 and the root-type exemption (Edge Cases, 2026-10-23):*

- No new production code is expected. This story proves that errors and warnings coexist in one report, with neither suppressing nor duplicating the other.
- **Fixture built from exempt or referenced records only**, so the total is exactly 4:
  - Error 1: Character `bad_no_prefix` (in `characters/`, filename = ID) fails F1, `field = "id"` (story 010). It references `faction_human_h`.
  - Error 2: Character `char_typo` carries the unknown key `stat_blok`, `field = "stat_blok"` (story 015). It references `faction_human_h`.
  - Warning 1: `faction_alien_a` and `faction_alien_b` share `signature_color` (shapes differ), each referenced by a Map, `field = "signature_color"` (story 019).
  - Warning 2: Character `char_sig` has `signature_move_id` also in its `move_ids` (`move_a`), `field = "signature_move_id"` (story 019).
- Characters and Maps are root types, and every Faction and Move in the fixture is referenced, so no unreferenced warning fires.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 023: the order of the entries.

---

## Files

- `tests/unit/content_data/fixtures/mixed_severity/`
- `tests/unit/content_data/content_data_mixed_severity_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS resolved: exact count kept because every fixture record is exempt or referenced). The developer implements against these — do not invent new test cases during implementation.*

- **AC-19**: Errors and warnings coexist.
  - Given: `fixtures/mixed_severity/` as in the Implementation Notes.
  - When: loaded into a fresh catalog.
  - Then: `load_all()` returns `FAILED`; `state == FAILED`; the report has **exactly 4** entries; error count is 2 and warning count is 2; and the four `(severity, record_id, field)` tuples are present: `(error, bad_no_prefix, id)`, `(error, char_typo, stat_blok)`, `(warning, faction_alien_a, signature_color)`, `(warning, char_sig, signature_move_id)`.
  - Edge cases: removing the two error records from a copy of the fixture gives `READY` with the same 2 warnings (warnings alone never fail).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_mixed_severity_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-009-one-error-fails-catalog.md`, `production/epics/content-catalog/story-010-id-format-validation.md`, `production/epics/content-catalog/story-015-structure-validation.md`, `production/epics/content-catalog/story-019-warning-cases.md`
- Unlocks: `production/epics/content-catalog/story-027-headless-validate-content.md`
