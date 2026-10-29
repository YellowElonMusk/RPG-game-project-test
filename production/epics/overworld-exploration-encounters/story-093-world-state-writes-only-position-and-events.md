# Story 093: World state mirrors the leader every frame and never auto-saves

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
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
**ADR Decision Summary**: `WorldState` is the single owner of map, position and facing, written every frame; every other field changes only on its own event, nothing per-frame emits a change signal, and the Overworld itself never calls the save writer.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: `WorldState` is a plain injected `RefCounted`, never an autoload (ADR-0012 §4); no engine-specific behaviour beyond that injection contract.

**Control Manifest Rules (this layer)**:
- Required: "`WorldState` … is the single owner of map, position and facing (written every frame) and of state that outlives a visit … nothing per-frame emits a change signal or reaches the save path" — source: ADR-0012 §4, ADR-0002 annotation (c)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-35 [L] (R15)** After any frame step, world state's map, position and facing equal the leader's. Other world-state fields change only on their events (a frame-step spy sees no write to them), and no world-state change signal is emitted on a frame with no event. The Overworld never calls the save writer (spy). (Save safety during transitions and overlays is Game State's to test: `game-state-scene-flow.md`.)

---

## Implementation Notes

*Derived from ADR-0012 §4 and GDD rule 15 ("Save moments"):*

- After any frame step, `world_state.map_id`/`party_pos`/`party_facing` must equal the leader's current map, position and facing (ADR-0012 §4: "written every frame").
- Every other field (`camp_returns`, `chapter_step`, resolved/opened/liberated per map, `stage_stored`, granted payoffs, `story_flags`) must change **only** on its own event. A frame-step spy running over an event-free run must record zero writes to any of them.
- Nothing about `WorldState` emits a per-frame change signal (ADR-0012 §4), and nothing per-frame reaches the save or autosave path. Assert a save-writer spy sees zero calls from the Overworld itself over the same run.
- Save safety during transitions and overlays is Game State's own test (`game-state-scene-flow.md`) — out of scope here; this story only proves the Overworld never initiates a save.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Load-time relocation off a blocked saved position (story 094).
- The full save/load round trip of every field (story 095).

---

## Files

- `src/overworld/world_state.gd`
- `tests/unit/overworld/world_state_frame_writes_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/world_state_frame_writes_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-001-leader-speed-from-move-input.md` (leader movement, the thing `WorldState` mirrors)
- Unlocks: `production/epics/overworld-exploration-encounters/story-094-load-relocates-off-a-blocked-saved-position.md`, `production/epics/overworld-exploration-encounters/story-095-save-round-trips-camp-interactables-and-flags.md`
