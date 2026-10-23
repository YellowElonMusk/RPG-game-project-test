# Story 034: The five roster `make_*()` factories are deleted, and every former caller builds enemies from records by ID

> **Epic**: Content Migration
> **Status**: Blocked — BLOCKED: needs story 029 and game-state-scene-flow Step 2's ChapterFlow strip and demo rewrite (ADR-0002 §8; see `production/epics/game-state-scene-flow/story-033-strip-chapter-flow-chapter-mode.md` and `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`)
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-turnbattle-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Faction Rule Modifiers (§5: "the `make_*()` factories are deleted with the ADR-0001 migration"; Migration Step 4); EPIC.md Steps 4–5 ("the now-unused factory bodies once every caller reads the catalog")
**ADR Decision Summary**: After every caller builds enemies from records by ID, the roster factories are deleted. ADR-0001 Step 3 kept them "the same shape" through the adapter phase; they go here, after the last caller has moved.
**ADR Version**: ADR-0011 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Harness and demo scenes call `ContentBootstrap.run()` in `_enter_tree()`, never `_init()`.

**Control Manifest Rules (this layer)**:
- Required: "Harness scenes and `validate-content.gd` call `ContentBootstrap.run()` in their own `_enter_tree()` / `_initialize()`, never `_init()`."
- Forbidden: "After ADR-0001 Migration Step 2, `ChapterFlow` must not construct `BattleCore`…" (coordinate with game-state Step 2; this story never re-adds construction there).
- Guardrail: none.

---

## Acceptance Criteria

*Migration criterion from ADR-0011 §5 / Migration Step 4, scoped to this story:*

- [ ] GIVEN the codebase, THEN no file defines or calls `make_clerk`, `make_supervisor`, `make_security_drone`, `make_middle_manager` or `make_ceo`; `chapter_flow.gd` (or what remains of it), `battle_hud_demo.gd` and `battle_debug_harness.gd` build their enemies through `EnemyAdapter`/`BattleFactory` from enemy IDs and their rules through the registry; `battle_hud_demo` shows the demo's shipped enemy names, `battle_debug_harness` shows its shipped names, and `chapter_flow` fight 1 shows Clerk ×3 (each list pinned from today's code at implementation, never changed), with one retained screenshot per scene at `production/qa/evidence/content-migration-034-<scene>.png`; and story 009's gate passes (the seam now builds enemies through `EnemyAdapter`).

---

## Implementation Notes

*Derived from ADR-0011 §5 / Step 4, the draft's Q2 resolution and the QA gate:*

- **The conflict this story settles (Q2).** ADR-0001 Step 3 keeps `make_*()` "the same shape"; ADR-0011 deletes them. They're kept through the adapter phase and deleted here. The seam edit (`enemy(id)` → `EnemyAdapter.from_record(...)`) is what keeps 003, 004 and 008 unchanged.
- The chapter's fight-by-fight roster (`_build_regular_enemies`: Clerk ×3, then Drone/Manager/Drone; then the boss) is **content too**. Under Game State it becomes Encounter records (`enc_`, ADR-0012), owned by the Overworld/Game State epics. Here, replace each factory call with its ID one-for-one and keep the sequence exactly. Do not create Encounter records in this epic. If game-state Step 2 has already reduced `chapter_flow.gd` to encounter sequencing, its roster becomes `enemy_ids`.
- Demos and harnesses are harness code, so ADR-0004 lets them call `ContentBootstrap.run()` in their own `_enter_tree()`. Run each scene, because **a parse check is not a run** (coding standards). Pin each scene's expected enemy-name list from today's code before switching it.
- Demo/harness squads (`SQUAD_*`, `TEST_SPECIAL_MP_COST`) are harness fixtures, not shipped content (Q8); they stay, and story 035 allowlists them.
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged; editing a characterization test or the frozen fixture is never the fix.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- game-state-scene-flow Step 2 (`production/epics/game-state-scene-flow/EPIC.md`): the ChapterFlow strip and demo rewrite.
- Encounter records (`enc_`): Overworld / Game State epics.
- Story 035: the CI lint.

---

## Files

- `src/battle/factions/bureaucratia.gd`, `src/battle/factions/megacorp.gd` (delete factories and their doc examples)
- `src/chapters/chapter_flow.gd` (roster by enemy ID)
- `src/battle/ui/battle_hud_demo.gd`
- `src/battle/battle_debug_harness.gd`
- `src/chapters/chapter_flow_demo.gd` (if it still builds a roster)
- `tests/unit/battle/helpers/battle_content_seam.gd` (seam edit: `enemy(id)` → `EnemyAdapter.from_record(...)`)
- `tests/integration/battle/battle_roster_callers_test.gd`
- `production/qa/evidence/content-migration-034-<scene>.png` (one per scene)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revision applied: expected roster per scene and evidence filenames in the criterion). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Factories gone; callers build from records.
  - **Test: no make_* left.**
    - Then: a grep of `src/` for the 5 `make_*` names finds no definition or call.
  - **Test: chapter roster sequence by ID.**
    - Then: the chapter's fight sequence of enemy IDs equals today's sequence (Clerk ×3, Drone/Manager/Drone, then the boss).
  - **Manual: scenes launch.**
    - Setup: launch `battle_hud_demo`, `battle_debug_harness` and the chapter flow (fight 1).
    - Verify: each shows its pinned enemy names.
    - Pass condition: names match the pinned lists; a screenshot per scene is retained at `production/qa/evidence/content-migration-034-<scene>.png` (run-and-observe).
  - Edge cases: story 009's gate passes with the seam's `enemy(id)` through `EnemyAdapter`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/battle/battle_roster_callers_test.gd` — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.
- Supporting: `production/qa/evidence/content-migration-034-<scene>.png`, one per scene.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-024-bureaucratia-roster-adapter.md`, `story-025-megacorp-roster-adapter.md`, `story-026-faction-rule-decisions-from-records.md`, `story-029-battle-factory-reads-enemy-records.md`; game-state-scene-flow Step 2 ChapterFlow and demo stories (`production/epics/game-state-scene-flow/story-033-strip-chapter-flow-chapter-mode.md`, `production/epics/game-state-scene-flow/story-034-battle-mode-wraps-battle-core.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`; not yet created)
- Unlocks: `production/epics/content-migration/story-035-no-hardcoded-battle-content-lint.md`
