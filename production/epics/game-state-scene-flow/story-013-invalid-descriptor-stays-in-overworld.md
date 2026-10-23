# Story 013: An invalid Encounter descriptor keeps the game in the Overworld and logs an error

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§8 interim flag; Implementation Guidelines: validate before any detach); ADR-0006: Battle Replay Ownership (§5 step 3: boss-count failure, noted only)
**ADR Decision Summary**: The Encounter descriptor is validated against `ContentCatalog.has_record()` at request time, before OUT and before any detach. Enemy IDs are checked only while the interim `validate_enemy_ids_against_catalog` flag is true.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0006 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure validator against the stub catalog. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Lookup API names are `get_record(type, id)`, `has_record(type, id)` …"
- Required: "A swap failure calls `rollback_swap()` …" (the path this story avoids by validating first).
- Required: "Consumers copy a record's values into their own runtime objects" (the validator only reads `has_record`; it never keeps a record).

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-14 [L]** GIVEN an invalid Encounter descriptor (unknown enemy ID), WHEN the battle is requested, THEN the mode stays Overworld and an error is logged.

---

## Implementation Notes

*Derived from ADR-0002 §8 and Implementation Guidelines:*

- `src/game_state/encounter_validator.gd` is pure: it takes the catalog and the config.
- Validation runs at **request time, before OUT and before any detach**. An invalid descriptor returns `REJECTED_INVALID_PAYLOAD`, logs an error, fires no signal, makes no loader call and leaves the probe unchanged.
- Checks: non-empty `encounter_id`; non-empty `enemy_ids`; known `faction_id` (`has_record(&"faction", id)`); each `enemy_id` through `has_record(&"enemy", id)` **only when `config.validate_enemy_ids_against_catalog` is true** (§8 interim flag, default `false`).
- **The AC's "unknown enemy ID" case runs with the flag `true`** in the config fixture. A second case with the flag `false` proves the other fields are still checked. Story 041 deletes the flag and collapses both cases.
- Runtime occurrence is a bug ("Content Data validation should catch this at boot"): log code `&"descriptor_invalid_runtime"`, `context.field` naming the failing field.
- `null` payload or `null` descriptor → `REJECTED_INVALID_PAYLOAD`, no crash.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 034: the boss-count check (ADR-0006 §5 step 3), which needs built `Combatant`s and so happens in the Battle mode's `setup()` during SWAP, a rollback path.
- Story 041: removing the interim flag.

---

## Files

- `src/game_state/encounter_validator.gd`
- `src/game_state/game_state_machine.gd` (calls the validator before OUT)
- `tests/unit/game_state/game_state_descriptor_validation_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-14 (flag on)**: `game_state_descriptor_validation_test.gd :: test_unknown_enemy_rejected_when_flag_on`
  - Given: `cfg.validate_enemy_ids_against_catalog = true`; stub catalog `has_record(&"enemy", "enemy_ghost") == false`, faction known.
  - When: `request_transition(BATTLE, payload with enemy_ids ["enemy_ghost"])`.
  - Then: `REJECTED_INVALID_PAYLOAD`; error code `&"descriptor_invalid_runtime"`, `context.field == &"enemy_ids"`; no signal; stub loader `begin_swap` count == 0; probe equal; mode OVERWORLD.
- **AC-14 (flag off)**: `test_other_fields_checked_when_flag_off`
  - Given: flag `false`.
  - When/Then: empty `encounter_id` → rejected; empty `enemy_ids` → rejected; unknown `faction_id` → rejected; unknown enemy with the flag false → accepted (documents the interim).
  - Edge cases: `null` payload or `null` descriptor → `REJECTED_INVALID_PAYLOAD`, no crash.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_descriptor_validation_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-012-failed-swap-rolls-back.md`, `production/epics/content-catalog/story-002-load-one-of-each-type.md` (`has_record` name and semantics)
- Unlocks: `production/epics/game-state-scene-flow/story-033-strip-chapter-flow-chapter-mode.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`, `production/epics/game-state-scene-flow/story-041-remove-interim-enemy-validation-flag.md`
