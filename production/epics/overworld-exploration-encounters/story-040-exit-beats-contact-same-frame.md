# Story 040: A map exit crossing on the same frame as contact wins, and contact is skipped

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: The per-frame order in Exploring is fixed: move the leader, check map exits, step symbols, check contact, check interaction — so an exit request on a frame pre-empts that frame's contact check entirely.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Pure per-frame ordering logic; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: Per-frame order: leader → exits (enter-edge only) → symbols → swept contact → interaction — ADR-0012 §5
- Forbidden: Never check contact on a frame where an exit request was made
- Guardrail: n/a

---

## Acceptance Criteria

- [ ] **AC-15 [L] (Edge Cases)** GIVEN contact and a MapExit crossing on the same frame, THEN only the exit request is made.

---

## Implementation Notes

*Derived from GDD Edge Cases ("If contact and a MapExit crossing happen on the same frame"):*

The GDD notes this cannot actually happen in shipped maps, since exits sit
inside safe zones where contact never counts (rule 12) — but the order must
still be correct and tested directly, independent of map data.

- Build a synthetic fixture (not a shipped map) where a leader's single frame of movement crosses both a `MapExit` rectangle and a symbol's contact radius simultaneously.
- Assert only the exit request fires that frame, and the contact check does not run at all (per the fixed per-frame order: exits are checked before symbols are stepped and before contact is checked).
- Assert the symbol's sub-state is unaffected by the skipped contact check — it is not an error or a race, just an ordering outcome.
- Do not assert anything about this situation being reachable on shipped maps — that guarantee belongs to the map-validation data stories (bands, safe zones), not this logic test.

---

## Out of Scope

- `story-038-contact-starts-encounter-once.md`: contact alone, no exit.
- `story-041-rejected-request-holds-contact-pending.md`: a rejected (not skipped) encounter request.

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/overworld_mode_exit_beats_contact_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/overworld_mode_exit_beats_contact_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-038-contact-starts-encounter-once.md`
- Unlocks: None
