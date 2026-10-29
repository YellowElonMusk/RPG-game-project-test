# Story 089: Defeat → Retreat against the boss goes to the pre-dungeon camp once it is passed, or the Town café before

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (§11 `register_camp`; Retreat → `CAMP`)
**ADR Decision Summary**: Passing a CampSpot's safe zone (no rest needed) calls `machine.register_camp(camp_id)` and fills `world_state.camp_returns[camp_id]`; `choose_retreat()` sends the party to `camp_returns[machine.last_camp_id]`, falling back to the region default camp when nothing is registered.
**ADR Version**: ADR-0012 2026-10-23 · ADR-0002 2026-10-21 (§11 revised 2026-10-23)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `register_camp`/`choose_retreat` are pure `GameStateMachine` calls with no scene-tree dependency; nothing engine-specific beyond the Foundation-layer probes already covering the machine's detach/freeze behaviour (ADR-0002 Engine Compatibility).

**Control Manifest Rules (this layer)**:
- Required: "The camp return point is derived, never stored twice: `camp_returns[machine.last_camp_id]`, falling back to the region default camp; registering a camp checks its ID against the map's CampSpots first; Retreat is `choose_retreat()` → CAMP" — source: ADR-0012 §4

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-33b [I] (R13, R13a)** After passing the pre-dungeon CampSpot's safe zone without resting, then Defeat → Retreat, the party is at the pre-dungeon camp, and the boss is unresolved. With no camp registered yet, Retreat goes to the Town café.

---

## Implementation Notes

*Derived from ADR-0012 §4 and GDD rule 13a ("Passing a CampSpot registers it"):*

- Entering a CampSpot's safe zone — not entering camp itself — is enough to register it (rule 13a extends `game-state-scene-flow.md` rule 9, where only *entering* camp records it): `OverworldMode` checks the `camp_id` against the current map's CampSpots and calls `machine.register_camp(camp_id)`, filling `world_state.camp_returns[camp_id]`.
- Test sequence: walk through the pre-dungeon camp's safe zone without resting → reach the boss → Defeat → choose Retreat. Assert the party lands at the pre-dungeon camp, and the boss stays unresolved (only Victory writes `respawn = never`, never a Defeat).
- Fallback case: with no camp registered at all, Retreat goes to the Town café — Paris's region default camp (`game-state-scene-flow.md` Edge Cases, "Retreat before any camp is registered").

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The boss contact descriptor itself (story 088).
- The boss staying resolved through a later Retreat, Save and Continue (story 090).

---

## Files

- `tests/integration/overworld/boss_retreat_camp_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/overworld/boss_retreat_camp_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-088-boss-contact-descriptor-flags.md`, `production/epics/game-state-scene-flow/story-020-register-camp-and-retreat-to-it.md`, `production/epics/game-state-scene-flow/story-021-retreat-region-default-and-no-camp.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-090-boss-stays-resolved-through-retreat-and-continue.md`

## Completion Notes (2026-10-29)

- Retreat used to enter a Camp mode with no scene. Story 089 adds an **interim** Camp mode (`src/game_state/modes/interim_camp_mode.gd`, registered for `Mode.CAMP`): a rest card whose `confirm` returns to the camp map at its CampSpot return EntryPoint. Camp & Party Management (not designed) replaces it.
- **Deviation:** camp returns come from `CampDirectory`, read from the map scenes at boot, instead of `world_state.camp_returns` (ADR-0012 §4): every return is fixed map data.
- `OverworldConfig.camp_mode_enabled` is now on, so the camp prompt Yes enters the Camp mode too.
- Evidence: `production/qa/evidence/story-089-camp-retreat/`.
