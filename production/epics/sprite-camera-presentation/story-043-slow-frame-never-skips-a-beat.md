# Story 043: a 0.5-second frame never skips a beat or double-fires its events

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership
**ADR Decision Summary**: `advance(delta)` clamps `dt = clampf(delta, 0.0, dt_max)` before stepping, and leftover `dt` past an event is dropped, never carried — so at most one timed entry finishes per call, and a slow frame can never skip a beat.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. A single headless test driving `advance()` with one oversized `delta` against a stub signal source.

**Control Manifest Rules (this layer)**:
- Required: "Only the Battle mode's `_process` may call `advance()`. No `Timer`, `Tween`, `SceneTree` or `Time` access may be added to the controller" (ADR-0006 Implementation Guidelines).
- Required: load-validation rule "`dt_max < beat_min`" (ADR-0006 §9) — the configuration invariant that makes the slow-frame clamp meaningful (a `dt_max` at or above `beat_min` could let a single frame still span past a beat's end despite the clamp).
- Forbidden: n/a — no Core Forbidden entry applies to this isolated clamp behaviour.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-39 [L]** (P-04) (slow frame) GIVEN `dt_max = 0.1`, WHEN a 0.5 s frame arrives mid-replay, THEN at most one beat ends on it, and every outcome still starts and ends exactly once.

---

## Implementation Notes

*Derived from ADR-0006 Decision §4 (`advance(delta)`, "Leftover `dt` is dropped, never carried"):*

- `advance()`'s step 2 clamps `dt = clampf(delta, 0.0, dt_max)` — a 0.5 s frame with `dt_max = 0.1` is clamped to exactly `0.1` before any clock advances, regardless of how much wall-clock time actually elapsed.
- "At most one timed entry finishes per call" is guaranteed by step 3's structure: only the one entry currently in progress is advanced, and any leftover `dt` past the event that finishes it (impact, or the entry ending) is discarded on that same call — it is never applied to the *next* entry within the same `advance()` call, which is what would otherwise let a slow frame cascade through several beats at once.
- This story's test must specifically assert the **absence** of a double-finish: with a stub battle queued with at least 2 outcomes, one oversized `advance(0.5)` call during the first outcome's wind-up must finish at most that one outcome, never both — and every `beat_started`/`beat_impact`/`beat_finished` signal for both outcomes must still eventually fire exactly once each across subsequent calls.
- This is a narrow, single-clause regression test distinct from `story-027`'s full parametrized `replay_time` suite — it exists because the slow-frame clamp is explicitly named as its own AC (and its own edge case in the ADR), not folded into the general formula cases.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-027-replay-time-holds-every-case.md`: the general per-case formula timing (this story is the one slow-frame regression case only).
- The `gate_stuck_warn_s` debug soft-lock warning (a different `PresentationConfig` knob, unrelated to this clamp).

---

## Files

- `src/battle/battle_replay_controller.gd`
- `tests/unit/battle/slow_frame_clamp_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/slow_frame_clamp_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet)
- Unlocks: None
