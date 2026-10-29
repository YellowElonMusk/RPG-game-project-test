# Story 065: Presses before the reveal and at replay start are latched correctly

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership
**ADR Decision Summary**: §6's `request_latch()`/`clear_latch()` only succeed while the state is `PLAYING`, and §3's `GATED` state blocks every entry from starting until `open_reveal_gate()`; a press while `GATED` (behind the wipe) or held into the replay from before it started must never latch, by construction of "a press counts only after the full reveal" (§6).
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API. The Input System emits exactly one `pressed` per physical press, at its start, with no key-repeat echoes (relied on here, ADR-0006 §6, Input rule 2/AC-2) — a `pressed` that arrives during a replay therefore began during it, so the controller needs no timestamp comparison.

**Control Manifest Rules (this layer)**:
- Required: `request_latch()`/`clear_latch()` only succeed while the state is `PLAYING` (ADR-0006 §6)
- Required: While `GATED`, `advance()` does nothing, no entry starts, and no press is accepted (ADR-0006 §3)
- Required: A press that begins during a replay is exactly a `pressed` event that arrives during it — no timestamp test is needed (ADR-0006 §6)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-60 [L]** (P-05) (presses before the reveal and at the replay's start)
  - GIVEN battle entry, WHEN Confirm or `fast_forward` is pressed on any frame while the wipe still covers the screen, THEN nothing is latched, nothing is submitted, and nothing carries over.
  - GIVEN a command submitted with Confirm and the key held into the replay, THEN the latch stays off for the whole replay.
  - GIVEN a new Confirm tap 5 frames after the replay starts, THEN the latch is latched.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

While the wipe covers the screen the controller is `GATED` (behind a `GATE` entry, §2–§3): `advance()` does nothing and no press is accepted, so a Confirm or `fast_forward` press during the wipe is simply dropped by the guard, never queued or remembered for later.
- The command menu's own Confirm submission happens before the replay exists (it is consumed by the command menu, §6 "Begins after"); a key held from that submission into the replay produces no new `pressed` event, so `request_latch()` is never called for it and the latch stays off.
- A fresh Confirm tap 5 frames into the replay is a genuine new `pressed`, arrives while `PLAYING`, and calls `request_latch()`, which succeeds exactly when `is_press_effective()` is true at that frame.
- No input-timestamp bookkeeping is implemented in the controller — the test instead constructs the exact `pressed`-event sequence (none during `GATED`, a held key that only ever produced one `pressed` before the replay, then a fresh `pressed` at frame 5) and checks the controller's state machine responds correctly to that sequence alone.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-058-menu-input-guard.md`: the menu-opening input guard (a UI Framework concern, not the controller's)
- `story-056-comfort-settings-change-mid-replay.md`: speed-setting changes during an active latch

---

## Files

- `src/battle/battle_replay_controller.gd`
- `tests/unit/battle/replay_latch_timing_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/battle/replay_latch_timing_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet)
- Unlocks: None
