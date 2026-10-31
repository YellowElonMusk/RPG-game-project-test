# Story 040: a Retry, Retreat or Quit mid-replay discards cleanly and never leaves a stale frame

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (pending commit)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-009`, `TR-presentation-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership
**ADR Decision Summary**: `cancel_pending_replay()` clears the queue, any entry in progress and the latch, emitting `replay_cancelled` if anything was discarded; `resync()` re-takes the settled snapshot and emits `display_resynced`, whose listeners reset the HUD, every sprite to `idle` (knockouts included), the punch offset and the indicator.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. Purely a headless signal-ordering test against a stub `BattleCore` emitting 5 outcomes and a turn, played through 2 beats, then discarded via Retry, Retreat or Quit.

**Control Manifest Rules (this layer)**:
- Required: "Every listener that shows battle state (`BattleHud`, every `CharacterSprite`, the punch, the indicator) must reset to the displayed state on `display_resynced`" (ADR-0006 Implementation Guidelines).
- Required: "The Battle mode must call `cancel_pending_replay()`, and stop its end-of-fight hold, on every `transition_started` from BATTLE (to another mode, or Battle → Battle for Retry), and again first thing in `restore_start_snapshot()`" (ADR-0006 Implementation Guidelines).
- Forbidden: "A handler must not call `cancel_pending_replay()`, `dispose()`, `submit_action()` or any queue method directly [during emission]; it uses `call_deferred()`" (ADR-0006 Implementation Guidelines, Re-entrancy) — relevant because this story's discard paths run from signal handlers and must respect the deferred-call rule.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-36 [L]** (P-04) (Retry or exit mid-replay) GIVEN a stub battle that emits 5 outcomes and a turn, played through 2 beats: **Retry**, when the retry transition starts: no beat, number or released-marker event fires for a discarded entry, and the end-of-fight hold, if running, is cancelled; behind the flash, the display resets — every number is cleared, every sprite is in `idle` (knockout poses included), the punch offset is 0 and the indicator is hidden; the displayed HP and MP equal the restored party values and the full-reset enemy values; the next replay starts from an empty queue. **Retreat and Quit:** when a transition away from Battle starts mid-replay or mid-hold, no event fires for a discarded entry, and no Victory or Defeat light plays afterwards. **On every path, on the next frame:** the punch offset is 0, the latch is cleared, and no beat-driven sprite animation advances.

---

## Implementation Notes

*Derived from ADR-0006 Decision §5 (Call order — Retry, Exit) and §8 (Displayed state, cancel, resync and teardown):*

- **Retry's order**: `cancel_pending_replay()` fires at `transition_started(BATTLE, BATTLE)` (stopping the end-of-fight hold too) and again, unconditionally, first thing in `restore_start_snapshot()` during SWAP — this story's test must assert both calls happen, not just that the net effect looks right, because the two-call pattern is deliberate (the second is a defensive no-op in the common case).
- **`resync()` must run after `start_battle(false)`**, not before — that call resets enemy HP, so a resync beforehand would leave the displayed enemy HP at defeated values. `resync()` emits `display_resynced`, and this story's test connects to that signal to assert the full reset (HUD numbers cleared, every sprite `idle`, punch offset 0, indicator hidden) rather than inspecting internal state directly.
- **Retreat/Quit** never call `resync()` — they call `cancel_pending_replay()` and stop the end-of-fight hold, then the Battle mode's `_exit_tree()` calls `dispose()`. No Victory/Defeat light request happens on this path, because `report_battle_outcome()` is never reached for a battle being left.
- **"No event fires for a discarded entry"** means the test must assert the *absence* of `beat_started`/`beat_impact`/`beat_finished`/marker-released signals for the 3 remaining outcomes and the turn that were still queued when the discard happened — a naive test that only checks final state could pass while an intermediate frame briefly showed a half-played beat.
- **Re-entrancy**: if this story's test harness auto-submits actions or drives discards from inside a signal handler, it must defer via `call_deferred()`, per ADR-0006's re-entrancy rule — calling `cancel_pending_replay()` synchronously from inside `advance()`'s own emission is a logged error in debug builds.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-030-retry-and-cancel-in-a-boss-fight.md`: the lighting side of Retry (this story is the queue/display side only).
- `story-033-command-menu-and-outcomes-wait-for-the-replay.md`: the normal (non-discarded) gating order.
- `story-049-boss-takeover-runs-on-one-clock.md`: a boss-specific Retry settle timing (`TAKEOVER_SETTLE`).

---

## Files

- `src/battle/battle_replay_controller.gd`
- `tests/unit/battle/retry_and_exit_discard_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/retry_and_exit_discard_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created and passing -- `tests/unit/battle/retry_and_exit_discard_test.gd` (4 tests: Retry, Quit and Retreat mid-replay, Quit mid-hold); full suite 1845/1845, exit 0, 0 orphans (2026-10-31).

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet); `story-027-replay-time-holds-every-case.md` (the beat/latch timing this discard path interrupts)
- Unlocks: None
