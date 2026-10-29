# Story 021: `validate-content.gd` exits 0 on the migrated `res://data`, with zero errors and only the expected warnings naming a migrated record

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented; Done still gated on stories 012 and 020)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-011` (and the whole migrated set, end to end)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Validation Criteria 1: "loads all current content with zero validation errors"); EPIC.md DoD ("`tools/ci/validate-content.gd` passes on the migrated data set")
**ADR Decision Summary**: The migrated data set must load through the full boot registration with zero validation errors; the headless validation script is the CI check.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: It is the first real content run of `ResourceLoader.list_directory()` discovery. The exported-build re-verification is content-catalog story 030; run that again on this data before the first migrated content ships (manifest Engine Verification). It is DEFERRED here because it needs an export.

**Control Manifest Rules (this layer)**:
- Required: "Headless validation script at `res://tools/ci/validate-content.gd`, exiting with `min(error_count, 1)` and accepting `--data-root=`."
- Required: "Validation runs over the complete record set before reporting."
- Guardrail: content-catalog story 029's load benchmark applies to the migrated set.

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Validation Criteria 1, scoped to this story:*

- [ ] GIVEN every record from stories 013–018, WHEN `godot --headless -s res://tools/ci/validate-content.gd` runs against `res://data` with every registrant from `ContentBootstrap.run()`, THEN the exit code is 0, the report holds no error, and the set of warnings naming a migrated record equals `tests/integration/battle/fixtures/expected_migrated_warnings.txt` (initially the five `move_*` squad-special unreferenced warnings).

---

## Implementation Notes

*Derived from ADR-0001 Validation Criteria and the QA gate (RC-4):*

- **Status.** Ready to implement, but **Done requires stories 012 and 020** (the full registrant set). Until then it runs with what is registered and records the gap in the Completion Notes; 012 and 020 each carry the clause "021's test stays green with the new registrant".
- **Expected warnings (RC-4).** The GDD's root-type exemption covers only Character, Map, OccupationStage, InputBindings, Combo and Item. With story 019 Blocked (Q1), no Character references the five squad-special Moves, so each produces an unreferenced-record warning. `expected_migrated_warnings.txt` holds exactly those five, one line each as `(severity, record_id, field)` with the reason "no Character records until Q1". The list empties when 019 lands or the squad is wired. Fix the test's expectation or the data, never the validator.
- Any other warning naming a migrated record (an unreferenced `faction_rule`, a Presentation `sprite_set_exists` hit, Q9) is a failure: fix the data (e.g. a placeholder asset), never the validator.
- **Subprocess call (pinned):** `OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/ci/validate-content.gd", "--", "--data-root=res://data"], output, true)`. It is a fresh process by construction.
- **Watch it fail:** a deliberately broken copy (Clerk `max_hp 1000` in a temp root passed via `--data-root`) gives exit 1.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `production/epics/content-catalog/story-027-headless-validate-content.md`: the script itself.
- `production/epics/content-catalog/story-030-exported-build-discovery.md`: exported-build discovery.
- Story 022: the no-paths scan.

---

## Files

- `tests/integration/battle/battle_migrated_data_validation_test.gd`
- `tests/integration/battle/fixtures/expected_migrated_warnings.txt`
- `.github/workflows/tests.yml` (validate-content step on `res://data`, if not already present)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: expected-warnings list (RC-4), Done gated on 012 and 020, pinned subprocess call). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: The migrated set validates.
  - Given: `res://data` with the records from 013–018.
  - When: the script runs as a subprocess (call above).
  - Then: the exit is 0, the report has 0 errors, and the warnings naming a migrated record equal the expected list.
  - Edge cases: a deliberately broken copy (Clerk `max_hp 1000` in a temp root via `--data-root`) gives exit 1, so the gate is watched failing. The exported-build re-verification (content-catalog 030) is noted as DEFERRED.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/battle/battle_migrated_data_validation_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-29: battle_migrated_data_validation_test.gd, 2 cases; full suite 596/596)

---

## Dependencies

- Depends on: `production/epics/content-migration/story-013-author-faction-records.md`, `story-014-author-enemy-named-attack-moves.md`, `story-015-author-bureaucratia-enemies.md`, `story-017-author-faction-rule-records.md`, `story-018-author-squad-special-moves.md`; `production/epics/content-catalog/story-027-headless-validate-content.md`; for Done: `production/epics/content-migration/story-012-register-stats-validators.md`, `story-020-enemy-reward-range-validation.md`
- Unlocks: `production/epics/content-migration/story-023-move-record-adapter.md`, `story-024-bureaucratia-roster-adapter.md` (and through them 025–029)

---

## Completion Notes

*2026-10-29, implementation (autonomous run, main session).*

- **Files**: `tests/integration/battle/battle_migrated_data_validation_test.gd` (2 cases) and `tests/integration/battle/fixtures/expected_migrated_warnings.txt`. `.github/workflows/tests.yml` needed no change, because it already runs `validate-content.gd` on `res://data` (story 027). `.github/` is still gitignored, a long-standing open item.
- **Expected warnings: empty, not five.** The story expected five unreferenced-record warnings for the `move_*` squad specials, because no Character record referenced them while story 019 was blocked. Story 019 was merged into 018, and the four `char_*` records now reference all five moves, so `res://data` validates with exit 0 and no warnings. The expected file is empty, with its reason documented. Watched failing: adding one fake expected line makes the test fail.
- **Deviation: the broken-copy mutation.** The story's example (Clerk `max_hp 1000`) passes today, because the stat range check is a Stats validator owned by story 012, which is blocked. This was confirmed by running it. The test instead points the Clerk at a move id that doesn't exist, which the current reference validator rejects (exit 1, `enemy_clerk | move_ids`). Once 012 lands, add the `max_hp 1000` case.
- **Done gate**: still requires stories 012 and 020, the full registrant set. Both stay Blocked until the Stats epic exists. This test runs with today's registrants, and 012 and 020 must keep it green.
