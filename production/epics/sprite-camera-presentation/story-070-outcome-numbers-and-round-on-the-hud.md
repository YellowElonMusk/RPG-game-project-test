# Story 070: Outcome numbers and the round number release on the right frame

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership
**ADR Decision Summary**: §2's display snapshots record `hp`, `mp`, status flags and `round_number` at every `BattleCore` emission, and §4's marker release applies a ROUND snapshot before emitting — so the HUD must show HP/MP/status from the *previous* snapshot until a beat finishes, and the round number and MegaCorp's per-round MP bill only on the frame the ROUND marker is released.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; this is controller/HUD-binding logic over already-defined signals (`beat_finished`, `round_advanced_after_replay`) and snapshot fields (ADR-0006 §2).

**Control Manifest Rules (this layer)**:
- Required: Each snapshot is the exact state at its point in the replay; before a beat finishes the HUD shows the previous snapshot (ADR-0006 §2, Validation Criteria "Display")
- Required: A ROUND marker's snapshot is applied to the displayed state before `round_advanced_after_replay` is emitted (ADR-0006 §4 step 4)
- Guardrail: HUD reads HP, MP, status, round and floating numbers only through the replay's displayed state (ADR-0005 TR-presentation-013)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-65 [L]** (P-04) (outcome numbers and the round on the HUD) GIVEN the AC-14b moves resolved in one replay, THEN:
  - the HUD shows exactly the numbers in AC-14b, each over its own combatant, at its beat's end;
  - the HP, MP and status shown before each beat ends equal the previous beat's values;
  - MegaCorp's per-round MP bill and the new round number appear on the frame the round change is released, not before.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

The HUD's displayed HP/MP/status is always one snapshot behind the live state until the entry carrying the newer snapshot finishes and releases it (§2–§4): a beat's number appears at `beat_impact` from that beat's own `BeatPlan.hp_changes`, but the HP/MP/status values shown stay at the *previous* snapshot until `beat_finished` applies the new one.
- This reuses AC-14b's already-defined sequence of resolved moves as its fixture — no new move resolution is introduced, only the display-state assertions around it.
- MegaCorp's per-round MP bill and the new round number are part of the ROUND marker's snapshot (§2 "taken after the round's upkeep"), so both must appear on the exact frame `round_advanced_after_replay` fires, never one frame earlier from the live `BattleCore` state.
- "Before each beat ends equal the previous beat's values" means the display-state getter (`get_display(c)`) must be checked on every frame of the wind-up and post-impact phases, not only at the start/end — a premature update anywhere in that window is a failure.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-064-old-damage-number-cleared.md`: a stale number's removal between two beats on the same target
- `story-067-end-of-fight-holds.md`: HUD behaviour after the replay ends, during the Victory/Defeat hold

---

## Files

- `src/battle/battle_replay_controller.gd`
- `tests/unit/battle/hud_display_state_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/battle/hud_display_state_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet)
- Unlocks: None
