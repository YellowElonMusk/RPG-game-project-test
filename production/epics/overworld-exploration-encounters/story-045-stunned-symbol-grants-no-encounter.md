# Story 045: A Stunned symbol overlapping the leader never starts a second encounter

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (`flee_grace_s` timing after `on_thawed`)
**ADR Decision Summary**: Stunned is deaf and intangible: no notice test, no contact, for `flee_grace_s`, after which the symbol becomes Returning.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Timer semantics tie to `mode_time`/`ow_dt` gating from ADR-0002 (mode time stops while the Menu is open); HIGH risk follows ADR-0002's own rating.

**Control Manifest Rules (this layer)**:
- Required: Stunned symbols are intangible — no notice test, no contact — ADR-0012 §5, GDD rule 5
- Forbidden: Never let a Stunned symbol make contact, even directly under the leader
- Guardrail: n/a

---

## Acceptance Criteria

- [x] **AC-19b [L] (R5, R7)** GIVEN a Stunned symbol overlapping the leader at any time during `flee_grace_s`, THEN no encounter starts. It is Stunned at `flee_grace_s − dt` and Returning at `flee_grace_s + dt`.

---

## Implementation Notes

*Derived from GDD rule 5 (Stunned row) and Edge Cases ("If a stunned symbol overlaps the leader"):*

- After a Fled push (story 044) lands the symbol overlapping the leader (or walk the leader onto it), assert the swept contact test never fires an encounter at any point during `flee_grace_s` — contact's eligibility check (read after the frame's movement) must reject a Stunned symbol outright.
- Apply the GDD timing rule: assert Stunned at `flee_grace_s − dt` and Returning at `flee_grace_s + dt`.
- The transition out of Stunned is to **Returning**, not directly to Patrol (GDD rule 5, Stunned row: "→ Returning when the stun ends") — assert that specific sub-state, since Returning is itself deaf until it reaches the resume point (story 033).

---

## Out of Scope

- `story-044-fled-symbol-stun-and-push.md`: entering Stunned.
- `story-033-returning-to-resume-point.md`: what Returning itself does.

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_stunned_no_contact_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_stunned_no_contact_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (full suite 824/824, 2026-10-29)

---

## Dependencies

- Depends on: `story-044-fled-symbol-stun-and-push.md`, `story-033-returning-to-resume-point.md`
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-29 (implemented, awaiting /story-done)
- STUNNED step ticks `flee_grace_s` then enters Returning; contact eligibility already excluded Stunned. A STUNNED state set without `on_fled` (no armed timer) holds, which keeps the older deaf-substate tests valid.
- Test: `tests/unit/overworld/symbol_brain_stunned_no_contact_test.gd` (2 cases, default and custom config).
