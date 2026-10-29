# Story 021: Noticing holds for notice_delay_s before Chasing starts, whatever the leader does meanwhile

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: Entering the leader's front-half notice radius with a reachable path moves a Patrol symbol to Noticing on that step's frame; Noticing is a timed hold of `notice_delay_s` that transitions to Chasing unconditionally once the delay elapses, even if the leader has since left the radius.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure timer/state-machine logic inside `SymbolBrain`; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: "Symbol AI lives in the pure `SymbolBrain` (sub-states... notice with cheap checks first then a bounded uniform-cost search...)" — source: ADR-0012 §5
- Guardrail: "Overworld symbol stepping + notice searches + repaths: ≤ 2.0 ms per frame at p99 on the GTX 1080-class PC and the Steam Deck" — source: `performance.per_system.overworld_ms`, ADR-0012 Performance

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-9b [L] (R5, notice)** GIVEN the leader entering the front half-plane at a centre distance below `symbol_chase_m`, with a reachable path, THEN the symbol is in Noticing on that frame's step. It is still in Noticing at `notice_delay_s − dt` and in Chasing at `notice_delay_s + dt`. GIVEN the leader leaving the radius during the delay, THEN Chasing still starts.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5's Noticing row and notice test:*

GDD rule 5: "Noticing: Stops, turns to face the leader, shows the notice cue.
Does not move. → Chasing after `notice_delay_s`, whatever the leader does
meanwhile." The notice test itself (radius, `SAFE`, component, bounded
search) is the gate that triggers entry into Noticing — this story tests the
timed hold and exit, not the gate's four checks (stories 022–025 and the
query-budget stories outside this batch own those).

- Use the harness's timing rule: pick a `dt` so `notice_delay_s / dt` is not a whole number, and assert Noticing at `notice_delay_s − dt` and Chasing at `notice_delay_s + dt`.
- Fixture the leader entering the front half-plane within `symbol_chase_m`, with a reachable path (component check and bounded search both pass) to trigger the Noticing entry on that exact frame.
- Mid-delay, move the leader back out of the radius and confirm Chasing still starts at the delay boundary regardless — "whatever the leader does meanwhile" is unconditional once Noticing has begun.
- `v_patrol`/`v_chase` are not relevant here (the symbol does not move during Noticing); only the timer and sub-state transition are under test.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 022: front/rear half-plane radius distinction.
- Story 023: the bounded path-cap reachability check.
- Story 026: facing-points-at-leader behaviour during Noticing (tested together with turn pause).

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_notice_delay_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_notice_delay_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (full suite 726/726 after stories 021-027, 2026-10-29)

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-020-patrol-loop-and-pingpong-traversal.md`
- Unlocks: None

---

## Completion Notes

**Implemented**: 2026-10-29
- `src/overworld/symbol_brain.gd`: Patrol runs the notice test before moving; a pass enters Noticing on that frame without moving. Noticing accumulates `dt` and enters Chasing once `cfg.notice_delay_s` has elapsed, ignoring the leader. `src/overworld/overworld_config.gd`: `notice_delay_s` (0.4) and the other notice/turn knobs (GDD defaults).
- Tests: `tests/unit/overworld/symbol_brain_notice_delay_test.gd` (5): Noticing at `delay - dt`, Chasing at `delay + dt` (dt 0.013), leader leaving mid-delay, patrolling symbol stops on the entry frame; default + custom config.
- `SymbolBrain.step()` widened to `step(dt, leader, grid, grace, cfg)` (stories 021-025 share one notice-test implementation in `src/overworld/symbol_brain.gd`). `tests/unit/overworld/symbol_brain_patrol_test.gd` (story 020) updated to the new signature, `heading` (the raw movement direction, renamed from `facing`), and `turn_pause_s = 0` so its uninterrupted arc-length checks still hold.

**Deviations**:
- Chasing has no movement yet: TODO(overworld), stories 031+.
- `leader_safe` is read from `grid` (`WalkGrid.is_safe()`) rather than passed in; `QueryBudget` is not in the signature yet (stories 028-030).
