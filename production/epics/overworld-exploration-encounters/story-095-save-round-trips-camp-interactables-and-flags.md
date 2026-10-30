# Story 095: Save and load round-trip the camp, interactables, payoffs, liberation and story-flag state

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: `WorldState` is the single owner of every field that outlives a visit — `camp_returns`, resolved/opened/liberated per map, granted payoffs, `stage_stored` and the interim `story_flags` — and the `overworld` save participant captures exactly it.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: No engine-specific behaviour; the save format itself belongs to Save/Load & Settings, which has no epic of its own yet (named here as a dependency, not a blocker) — this story exercises `WorldState`'s own data against the test harness's stub save writer/reader, not a real save file.

**Control Manifest Rules (this layer)**:
- Required: "`WorldState` (injected `RefCounted`, never an autoload) is the single owner of map, position and facing … and of state that outlives a visit (`camp_returns`, `chapter_step`, resolved/opened/liberated per map, `stage_stored`, payoffs, interim `story_flags`)" — source: ADR-0012 §4, ADR-0002 annotation (c)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-35c [L] (R15)** Save and load round-trips the last camp registered, opened interactables (gag `change` responses included), granted payoffs, liberated sets, `stage_stored` and the interim story flags.

---

## Implementation Notes

*Derived from ADR-0012 §4 and GDD rule 15 ("Save moments"):*

- Build a fixture `WorldState` exercising every field the GDD says outlives a visit: the last camp registered (`camp_returns`, derived from `machine.last_camp_id`); opened interactables, gag `change` responses included (`mark_opened`); granted payoffs (`grant_payoff`'s once-only ledger); liberated marker sets per map (`liberate`); `stage_stored` per map; and the interim `story_flags`.
- Round-trip it through the test harness's stub save writer/reader (no real Save/Load system required — Save/Load & Settings has no epic of its own yet, named as a dependency rather than a blocker) and assert field-for-field equality after the round trip.
- This complements story 093 (per-frame write discipline) and story 094 (load-time relocation): this story proves the **content** of a save/load cycle, not when writes happen or where the leader lands.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Per-frame write discipline (story 093) and load-time position relocation (story 094).
- `Continue`'s per-visit symbol reset (story 096).

---

## Files

- `src/overworld/world_state.gd`
- `tests/unit/overworld/world_state_save_round_trip_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/world_state_save_round_trip_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-093-world-state-writes-only-position-and-events.md`, `production/epics/overworld-exploration-encounters/story-091-permit-counter-static-behavior.md`, Save/Load & Settings (no epic yet — named as a dependency, not Blocked)
- Unlocks: `production/epics/overworld-exploration-encounters/story-090-boss-stays-resolved-through-retreat-and-continue.md`, `production/epics/overworld-exploration-encounters/story-096-continue-resets-symbols-to-patrol-origin.md`

## Completion Notes (2026-10-30)

- Granted payoffs, liberated sets and `stage_stored` do not exist yet (stories 050, 059, 053); they join `WorldState.to_dict()` with those stories. Camp, checkpoints, gag state (story flags) and flags round-trip today.
