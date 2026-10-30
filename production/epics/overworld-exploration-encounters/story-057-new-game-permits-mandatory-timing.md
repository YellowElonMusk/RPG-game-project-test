# Story 057: New Game sets permits_mandatory before the first input, and the segment always loads at stage 2

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-009`, `TR-overworld-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `null` payload (New Game) drives `WorldState.reset_to_new_game()`, which sets `OverworldConfig.new_game_map_id`/`new_game_entry`; the chapter's opening step sets `permits_mandatory` before the player has control, so the overworld segment's only reachable stage is 2.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API in this path; risk comes from citing ADR-0002's Game State transition and input-lock sequencing, which is HIGH per its own Engine Compatibility row.

**Control Manifest Rules (this layer)**:
- Required: Entry paths — `MapEntryPayload` → marker (+respawn); `LoadedSave` → saved position, no respawn; `null` → New Game — source: ADR-0012 §4
- Forbidden: Never write `WorldState` from `OverworldMode._ready()` — a rolled-back map change would leave it naming the wrong map — source: ADR-0012 §4
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-23d [I] (R8, R18 registry)** On a New Game, `permits_mandatory` is set before the first input is accepted; the overworld segment's first load is at stage 2, with its decree gag at both EntryPoints, whatever route the player takes through Town. Beating any symbol, entering any map or registering any camp sets no stage-raising flag (flag spy).

---

## Implementation Notes

*Derived from ADR-0012 §4 and GDD rule 8, tested against the real Game State:*

- `null` (New Game) entry path: `reset_to_new_game(cfg)` sets `OverworldConfig.new_game_map_id` and its `new_game_entry` (ADR-0012 §4 entry-path table).
- Rule 8, Paris stages: `permits_mandatory` is set on the chapter's **opening step**, before the player has control — the occupier acts first, so nothing the squad does causes it (Pillar 2: never a reprisal).
- The segment's reachable-stage set, derived from the step list, is exactly `{2}` (`occupation_stage` Formulas example), so its first load is always stage 2, whichever Town route reaches it.
- **Flag spy**: drive a full Victory, a map entry and a camp registration through the real Game State and assert the stage-raising flag write count stays zero for each — rule 8's "never a reprisal" clause is the thing under test, not just the opening-step trigger.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-055-paris-map-stage-and-decree-registry-rules: the CI registry/scheduling check (AC-23b)
- story-056-decree-gag-stage-eligibility: decree-gag runtime eligibility (AC-23c)

---

## Files

- `src/overworld/world_state.gd` (`reset_to_new_game`, `chapter_step`)
- `src/overworld/overworld_config.gd` (`new_game_map_id`, `new_game_entry`)
- `tests/integration/overworld/new_game_permits_mandatory_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/overworld/new_game_permits_mandatory_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-053-occupation-stage-formula.md` (`occupation_stage`), `story-055-paris-map-stage-and-decree-registry-rules.md`, `story-056-decree-gag-stage-eligibility.md`, `production/epics/game-state-scene-flow/` (done; New Game input lock)
- Unlocks: `production/epics/overworld-exploration-encounters/story-058-marker-activation-slots-by-stage-and-cap.md`

## Completion Notes (2026-10-30)

- **Deviation:** the segment decree gag at both EntryPoints waits for decree gags (story 056). The flag, its timing and the stage-2 first load are done; the opening step flags come from `data/chapters/chapter_paris_steps.tres`.
