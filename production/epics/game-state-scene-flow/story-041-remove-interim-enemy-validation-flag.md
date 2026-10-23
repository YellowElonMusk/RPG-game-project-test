# Story 041: Remove the interim validate_enemy_ids_against_catalog flag

> **Epic**: Game State & Scene Flow
> **Status**: Blocked — BLOCKED: depends on content-migration's enemy-record migration (ADR-0001 enemy records: `production/epics/content-migration/story-015-author-bureaucratia-enemies.md`, `production/epics/content-migration/story-016-author-megacorp-enemies.md`, and the factory adapter `production/epics/content-migration/story-029-battle-factory-reads-enemy-records.md`), none Done yet.
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md` (migration story: no GDD acceptance criterion)
**Requirement**: `TR-gamestate-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§8: "The flag is deleted, and full validation becomes unconditional, in Migration Step 3 or when the enemy migration lands, whichever comes first"; Migration Plan Step 3); ADR-0010: Turn Battle System (§3: "The table and the flag are deleted together")
**ADR Decision Summary**: Once enemy records exist, the interim flag goes and enemy-ID validation of the Encounter descriptor becomes unconditional; `BattleFactory`'s interim enemy-ID → factory table goes with it.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0010 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Deletion and a test collapse. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Static factories become adapters: they read the catalog record and build today's runtime `Move` / `Combatant` objects. `BattleCore` never touches a catalog record."
- Required: "Characterization tests are written against today's hardcoded factories before migration and rerun unchanged after it" (032's and content-migration's suites must still pass).
- Required: "Lookup API names are `get_record(type, id)`, `has_record(type, id)` …"

---

## Acceptance Criteria

*Migration story: the criterion is ADR-0002 Migration Plan Step 3.*

- [ ] **Step 3** — "Remove the interim validation flag (`validate_enemy_ids_against_catalog`) once ADR-0001's enemy-record migration lands, which must happen before Step 4."
  1. [ ] An unknown enemy ID is rejected with no config switch.
  2. [ ] Every `ChapterMode` descriptor's `enemy_ids` resolve through `catalog.get_record(&"enemy", id)` on the real `data/` catalog.
  3. [ ] Grep gate: no reference to `validate_enemy_ids_against_catalog` anywhere in `src/`, `data/` or `tests/`.
  4. [ ] Story 032's and content-migration's Step 0 suites pass unchanged.
  5. [ ] A run-and-observe screenshot of the demo is retained after the content-source change.

---

## Implementation Notes

*Derived from ADR-0002 §8 and ADR-0010 §3:*

- Remove the field from `TransitionConfig` and the key from `data/config/transition_config.tres`; make the enemy check in `encounter_validator.gd` unconditional.
- **`BattleFactory`'s interim table.** ADR-0010 deletes the table and the flag together. Content-migration story 029 already has deleting the table as its criterion; if it has landed, this story only verifies the table is gone (enemies always from `catalog.get_record(&"enemy", id)`). Otherwise remove it here.
- Story 013's flag-on and flag-off cases collapse into one unconditional case; the "flag true" fixture disappears.
- `ChapterMode`'s descriptors must now name enemy **record** IDs that exist. Run the rewritten demo (035) and retain a run-and-observe screenshot, because the battle content source changed.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `production/epics/content-migration/`: authoring the enemy records and the factory adapter.
- ADR-0002 Migration Step 4: retiring `ChapterMode` when the Overworld ships (Overworld epic).

---

## Files

- `src/game_state/transition_config.gd` (field removed)
- `data/config/transition_config.tres` (key removed)
- `src/game_state/encounter_validator.gd` (enemy check unconditional)
- `src/battle/battle_factory.gd` (interim table removed, if content-migration 029 has not already)
- `tests/unit/game_state/game_state_descriptor_validation_test.gd` (cases collapse)
- `tests/unit/battle/battle_factory_test.gd`
- `production/qa/evidence/game-state-041-demo-enemy-records-[date].png`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE; dependencies named). The developer implements against these — do not invent new test cases during implementation.*

- **Check 1**: `game_state_descriptor_validation_test.gd :: test_unknown_enemy_always_rejected`
  - Given: `cfg` has no `validate_enemy_ids_against_catalog` field; the stub catalog lacks `"enemy_ghost"`.
  - When: `request_transition(BATTLE, payload with enemy_ids ["enemy_ghost"])`.
  - Then: `REJECTED_INVALID_PAYLOAD`, error logged, mode OVERWORLD, probe equal.
- **Check 2**: `battle_factory_test.gd :: test_enemies_from_catalog`
  - Then: every `ChapterMode` descriptor's `enemy_ids` resolve through `catalog.get_record(&"enemy", id)` on the real `data/` catalog.
- **Checks 3–5 (checklist)**: grep for `validate_enemy_ids_against_catalog` in `src/`, `data/`, `tests/` returns nothing; 032 and content-migration Step 0 suites pass unchanged; run-and-observe screenshot retained after the content-source change.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_descriptor_validation_test.gd` and `tests/unit/battle/battle_factory_test.gd` — must exist and pass. Gate level: BLOCKING.
- Run-and-observe: `production/qa/evidence/game-state-041-demo-enemy-records-[date].png` retained.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-013-invalid-descriptor-stays-in-overworld.md`, `production/epics/game-state-scene-flow/story-034-battle-mode-wraps-battle-core.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`; `production/epics/content-migration/story-015-author-bureaucratia-enemies.md`, `production/epics/content-migration/story-016-author-megacorp-enemies.md`, `production/epics/content-migration/story-029-battle-factory-reads-enemy-records.md`
- Unlocks: ADR-0002 Migration Step 4 (retire `ChapterMode` when the Overworld ships; Overworld epic)
