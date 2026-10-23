# Story 009: CI runs the Step 0 suite on every push and fails if any characterization test or its expected-values fixture differs from the Step 0 baseline

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: None (process gate)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 5: "Point Validation Criteria's regression check at the Step 0 tests"; Validation Criteria 2)
**ADR Decision Summary**: The Step 0 characterization tests are the migration's regression check and must pass unchanged after every step. This story makes "unchanged" checkable: a checked-in SHA-256 manifest of the Step 0 files and a headless GDScript checker that CI runs on every push.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `FileAccess.get_sha256(path)` is a long-standing static. A `-s` script extends `SceneTree` and does its work in `_initialize()`, then `quit(code)`.

**Control Manifest Rules (this layer)**:
- Required: "Characterization tests are written against today's hardcoded factories before migration and rerun unchanged after it."
- Required: "Run each verification or characterization pass in a fresh engine process."
- Guardrail: the checker hashes a handful of files; no budget concern.

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 5 and Validation Criteria 2, scoped to this story:*

- [ ] GIVEN `tools/ci/characterization_baseline.sha256` (path + SHA-256 per file, checked in when 002–008 close), WHEN `tools/ci/check_characterization_unchanged.gd` runs headless, THEN it exits 0 only if the set of files matching `tests/unit/battle/*_characterization_test.gd`, `tests/unit/battle/fixtures/characterization_expected.gd` and `tests/unit/battle/fixtures/scripted_fight_commands.gd` equals the manifest's set and every hash matches; it exits 1 and names each file on any mismatch, extra file, missing file, or missing or unparsable manifest. CI runs it as a step, and runs `tests/unit/battle/` in its own process. The seam (`tests/unit/battle/helpers/battle_content_seam.gd`) is excluded.

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 5 and the QA gate (RC-6; option chosen: checked-in hash manifest + GDScript checker):*

- **Why a hash manifest, not a git SHA (RC-6).** CI's `actions/checkout@v7` runs depth 1 without `fetch-depth`, so `git diff <sha>` has no object to compare against. The manifest needs no git history and runs on Windows dev machines. (The rejected alternative was bash with `fetch-depth: 0`.)
- Put the comparison in a pure, testable class (`CharacterizationBaseline.diff(manifest_path, root) -> PackedStringArray` of offending paths) and keep `check_characterization_unchanged.gd` a thin `SceneTree` wrapper that prints each offending path and quits with `min(count, 1)`, or 1 when the manifest is missing or unparsable. **It fails closed.**
- **Line endings.** Pin LF for the gated paths in `.gitattributes` (`tests/unit/battle/*_characterization_test.gd text eol=lf`, and the two fixture files), or Windows checkouts with `core.autocrlf` hash differently.
- It sits first among the post-Step-0 stories because every adapter story's Definition of Done is "the gate passes". Without it, "unchanged" is a promise, not a check.
- **Changing the manifest is a reviewed change.** The Completion Notes of any change must say why. The only legitimate reason is a Step 0 test that was wrong about *today's* behaviour, found before any adapter landed.
- The seam is excluded on purpose: it is the one file later stories edit to follow API changes (story 001).
- The gate's own test is named `battle_characterization_gate_test.gd` (not `*_characterization_test.gd`), so it is not inside its own gated set. Its fixtures are temp copies under `user://` created and removed by the test.
- **Watch it fail:** on a branch, edit one pinned constant, confirm the script exits 1 naming the file, and revert.
- ADR-0001's Validation Criteria text is updated by technical-director to cite this checker (a doc annotation, not a decision change).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 002–008: the characterization tests themselves.
- Story 021: the content-validation CI step.
- Story 035: the battle-content lint.

---

## Files

- `tools/ci/characterization_baseline.gd` (`class_name CharacterizationBaseline`, static `diff()`)
- `tools/ci/check_characterization_unchanged.gd` (headless entry point)
- `tools/ci/characterization_baseline.sha256` (the checked-in manifest)
- `.gitattributes` (LF pinning for the gated paths)
- `.github/workflows/tests.yml` (one added step: the checker; the battle suite in its own process)
- `tests/unit/battle/battle_characterization_gate_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: SHA-256 manifest instead of git history, fail-closed, added/deleted-file detection, LF pinning, retyped Config/Data → Logic). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: The gate passes only on an unchanged set.
  - **Test: unchanged passes.**
    - Given: a temp copy of the gated files and their manifest.
    - When: `CharacterizationBaseline.diff(manifest, root)`.
    - Then: the result is empty.
  - **Test: one byte changed fails.**
    - When: one constant in the copied fixture is edited.
    - Then: the result names that file.
  - **Test: added or deleted file fails.**
    - When: `x_characterization_test.gd` is added, or one gated file is removed.
    - Then: it is named.
  - **Test: missing manifest fails closed.**
    - Then: the checker's exit is 1 (also for an unparsable manifest).
  - Edge cases: line-ending normalisation; the same content with CRLF endings would hash differently, which `.gitattributes` prevents (assert the `.gitattributes` lines exist).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_characterization_gate_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-002-characterize-squad-specials.md`, `story-003-characterize-bureaucratia-roster.md`, `story-004-characterize-megacorp-roster.md`, `story-005-characterize-moves-damage.md`, `story-006-characterize-faction-rule-decisions.md`, `story-007-characterize-faction-rule-presentation.md`, `story-008-characterize-scripted-fights.md`
- Unlocks: stories 023–035 in `production/epics/content-migration/` (each closes on this gate): `story-023-move-record-adapter.md` through `story-035-no-hardcoded-battle-content-lint.md`
