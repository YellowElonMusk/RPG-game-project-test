# Story 029: `BattleFactory.build()` builds every enemy from its Enemy record by descriptor ID, the interim ID → factory table is deleted, and the Step 0 suite passes unchanged

> **Epic**: Content Migration
> **Status**: Blocked — BLOCKED: needs `src/battle/battle_factory.gd` with its interim table (game-state-scene-flow Step 2, Battle mode story; see `production/epics/game-state-scene-flow/story-034-battle-mode-wraps-battle-core.md`)
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-turnbattle-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Turn Battle System (§3 BattleFactory, "Interim path"; Migration Step 7: "`BattleFactory` reads enemy records, and the interim table and flag are deleted"). Also ADR-0011: Faction Rule Modifiers (§4: "`create()` does no lookups. `BattleFactory` … does the lookup").
**ADR Decision Summary**: Under Game State, battles are built only by `BattleFactory.build()` from an Encounter descriptor. Its interim ID → factory table is replaced by Enemy records read through `EnemyAdapter`.
**ADR Version**: ADR-0010 2026-10-22 · ADR-0011 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required (Feature, ADR-0010): "Under Game State, a `BattleCore` must be built only by `BattleFactory.build()`. Test and harness code may construct it directly."
- Required: "Static factories become adapters: they read the catalog record and build today's runtime `Move` / `Combatant` objects."
- Guardrail: one build per battle start.

---

## Acceptance Criteria

*Migration criterion from ADR-0010 §3 / Migration Step 7, scoped to this story:*

- [ ] GIVEN an `EncounterDescriptor` with `enemy_ids` [`enemy_clerk`, `enemy_supervisor`], WHEN `BattleFactory.build(payload, catalog, rules, stats_config, config, rng)` runs, THEN the core's enemies are new Combatants built by `EnemyAdapter` from the catalog, in descriptor order, each with `record_id`; an unknown enemy ID returns a `BattleBuildResult` with an error and a `null` core; the interim table no longer exists in the source; and story 009's gate passes (008 green, unchanged).

---

## Implementation Notes

*Derived from ADR-0010 §3 / Step 7 and ADR-0011 §4:*

- ADR-0010 says "the table and the flag are deleted together". The flag (`TransitionConfig.validate_enemy_ids_against_catalog = false`, ADR-0002 §8) is game-state-scene-flow's Step 3, unblocked by this epic finishing. This story deletes the table; its Completion Notes must notify that epic. Coordinate the two in one sprint, so the flag doesn't outlive the table by long.
- The table's symbol name isn't known until game-state Step 2 builds it. Pin it from that story and grep for it here.
- The rule half (`faction` → `rule_id` → `registry.create()`) is built by game-state Step 2 against story 026's registry. If it isn't there yet, it's in scope here (the same three steps, ADR-0010 §3).
- Why Integration: the Battle mode payload, catalog, registry and core are four collaborators across two epics.
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged; editing a characterization test or the frozen fixture is never the fix. Re-run in a fresh process.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- game-state-scene-flow Step 2/3 (`production/epics/game-state-scene-flow/EPIC.md`): building `BattleFactory` and deleting the flag.
- Story 034: deleting the roster factories and switching callers.

---

## Files

- `src/battle/battle_factory.gd` (enemy loop through `EnemyAdapter`; delete the interim table)
- `tests/integration/battle/battle_factory_records_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Enemies built from descriptor IDs.
  - Given: `enemy_ids [enemy_clerk, enemy_supervisor]` and a READY catalog.
  - When: `BattleFactory.build(...)`.
  - Then: the core's enemies are new Combatants in order, with `record_id`.
  - Edge cases: an unknown ID gives `BattleBuildResult.error` set and `core == null`. A grep finds no interim-table symbol. Story 009's gate passes (008).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/battle/battle_factory_records_test.gd` — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-024-bureaucratia-roster-adapter.md`, `story-025-megacorp-roster-adapter.md`, `story-026-faction-rule-decisions-from-records.md`; game-state-scene-flow Step 2 Battle mode story (`production/epics/game-state-scene-flow/story-033-strip-chapter-flow-chapter-mode.md`, `production/epics/game-state-scene-flow/story-034-battle-mode-wraps-battle-core.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`; not yet created)
- Unlocks: `production/epics/content-migration/story-034-delete-roster-factories.md`; outside this epic, game-state-scene-flow Step 3 (delete `TransitionConfig.validate_enemy_ids_against_catalog`, ADR-0002 §8)
