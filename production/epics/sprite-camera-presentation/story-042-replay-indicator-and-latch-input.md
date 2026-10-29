# Story 042: the replay indicator shows the right state and every press either latches, un-latches or is refused

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership
**ADR Decision Summary**: `request_latch()` and `clear_latch()` each change the latch and return true only under specific state/effectiveness conditions, emitting `latch_changed`; a press that changes nothing produces exactly one refusal and changes nothing; `press_effective_changed` drives the indicator's passive/active state.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. Purely headless state-machine logic against the controller's own public surface (`request_latch`, `clear_latch`, `is_press_effective`), driven by explicit `advance()` deltas and synthetic press events — no UI or Input System integration is exercised by this story.

**Control Manifest Rules (this layer)**:
- Required: "The UI Framework must report a replay-indicator click as its own event, never as `confirm`, so a click on the latched indicator can un-latch. A `false` from `request_latch()` or `clear_latch()` must produce the refusal feedback" (ADR-0006 Implementation Guidelines).
- Required: "During a replay, `confirm`, `fast_forward` and `cancel` presses must be consumed by the latch methods and must never be buffered or passed on" (ADR-0006 Implementation Guidelines).
- Forbidden: "No `Timer`, `Tween`, `SceneTree` or `Time` access may be added to the controller [besides `advance()`]" (ADR-0006 Implementation Guidelines).

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-38 [L]** (P-05) (input during a replay, the indicator): **Pressing:** while active and unlatched, Confirm, `fast_forward` and an indicator click each latch, and no command is submitted. While latched, Cancel and an indicator click each un-latch from the next frame. **Refusal:** a press that changes nothing (Confirm while latched, Cancel while unlatched, any press while passive) produces exactly one refusal event and changes nothing. Cancel never opens the Menu. **Passive state:** the indicator is passive on exactly the frames where `press_effective` is false. With only knockout holds left, it is passive. During a first-encounter takeover, it is passive with "Speed up boss entrances" Off and active with it On. **Text:** the indicator shows on every frame of a replay (the boss takeover included) and on no other frame, with the state's text from the frame after each change. **After the replay:** the command menu that opens afterwards focuses the default of rule 9, with nothing submitted.

---

## Implementation Notes

*Derived from ADR-0006 Decision §6 (Speed, the latch and input):*

- `request_latch() -> bool` sets the latch and returns true only if `PLAYING`, not already latched, and `is_press_effective()` is true; otherwise it changes nothing and returns false. `clear_latch() -> bool` is the mirror: clears and returns true only if it was set **and** effective, otherwise false. Every false return is this story's "refusal" case — the test asserts the Battle mode's refusal feedback path is invoked exactly once per such press, with no state change.
- "An indicator click" is reported as its own UI event, never as `confirm` (ADR-0006 Implementation Guidelines) — this story's input-routing test must drive that event distinctly from a `confirm` press, so a click on a latched indicator can un-latch exactly as Cancel does, per the GDD's design.
- `is_press_effective()` is true iff some remaining time depends on the latch: a remaining non-debug wind-up, a remaining `TAKEOVER_SETTLE` hold, or a remaining `TAKEOVER_FULL` hold with `speed_up_boss` On. Holds after impact never count — a replay with only knockout holds left is therefore never press-effective, which is this AC's explicit "with only knockout holds left, it is passive" case.
- `press_effective_changed` fires on every change, driving the indicator's passive/active text; the indicator itself shows on every frame where `is_replaying()` is true (boss takeover included) and hides otherwise — this is a direct mapping from controller state to indicator visibility, with no separate timer.
- "Cancel never opens the Menu" is an input-routing guarantee, not a controller one: `clear_latch()`'s consumption of the Cancel press (ADR-0006 §6) must happen before the Menu's own `menu` action binding is considered, which this story's test exercises by asserting no Menu-open call occurs alongside a Cancel press during a replay.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-049-boss-takeover-runs-on-one-clock.md`: the takeover's own duration formula (this story only needs `is_press_effective()`'s boolean outcome during one).
- The UI Framework's actual refusal feedback widget and indicator rendering (ADR-0008, a separate epic).
- `story-027-replay-time-holds-every-case.md`: the general speed/latch formula on wind-up and hold durations.

---

## Files

- `src/battle/battle_replay_controller.gd`
- `tests/unit/battle/replay_latch_input_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/replay_latch_input_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet); the UI Framework's indicator-click event and refusal feedback (ADR-0008, not yet built — this story stubs both as injected `Callable`s)
- Unlocks: None
