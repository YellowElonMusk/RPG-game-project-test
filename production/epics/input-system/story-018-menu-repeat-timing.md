# Story 018: A held direction steps exactly at `step_time(k)` on a fixed tick, including a non-multiple interval and every due step in order during a hitch, and stops on release

> **Epic**: Input System
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-002`, `TR-input-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§1 menu-repeat timers, §8 `nav_*` at `step_time(k)`)
**ADR Decision Summary**: Menu steps are derived `nav_up/down/left/right` actions emitted at `step_time(k)` from `InputConfig.repeat_delay`/`repeat_interval` on the injectable `tick(delta)` clock. During a hitch every due step fires in order, never merged; Input emits them in every mode.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**`action_pressed`/`action_released` fire on edges; `action_held` fires every `tick` while held.** `nav_*` are derived actions, never bound directly"
- Required: "**`InputResolver` (`RefCounted`) owns the binding table ... Driven only through `feed_event()`, `tick()`, `set_window_focused()` and `on_joy_connection()`**"
- Required: "**Bindings are a catalog record** (`bindings_` prefix); **tuning values** (deadzone, repeat timing, ...) are a project config (`InputConfig`)"
- Guardrail: "**Input**: one dictionary lookup per device event, negligible per `tick`"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-7** With the harness's fixed tick Δt = 1/60 s, a direction held for T seconds produces, for every k with `step_time(k) ≤ T`, one step on the first tick whose time is ≥ `step_time(k)`, never earlier (a step due exactly at T counts). Tick time is computed as n × Δt from the integer tick count n, never by summing floats, and `≥` compares with a tolerance of 1e-9 s. A second case uses a `repeat_interval` that is not a multiple of Δt. A third case uses one 0.25 s tick spanning several due times: every due step fires on that tick, in order, never merged. Releasing stops further steps.

---

## Implementation Notes

*Derived from ADR-0003 §1, §8 and the GDD Formulas:*

- **Formula.** `step_time(k) = 0 for k = 0; repeat_delay + (k − 1) × repeat_interval for k ≥ 1`. Step k = 0 fires **on the press event itself** (in `feed_event`), with zero latency. Later steps fire in `tick()`.
- **Time keeping (pinned, QL-STORY-READY 2026-10-23).** The resolver keeps `elapsed: float` since the direction's press, adds `delta` in `tick()`, and fires step k when `elapsed + 1e-9 >= step_time(k)`. Step 0 fires in `feed_event`. The **test** computes each step's expected tick as the smallest integer n with `n * DT + 1e-9 >= step_time(k)` (integer n × Δt, never a running float sum). Do not let float drift make a step due exactly at T fire one tick late.
- **Catch-up.** On one tick whose span covers several `step_time(k)`, emit every due step, in order, each as its own `action_pressed(nav_*)`, never merged (GDD rule 5).
- **Directions.** A direction for menu purposes is the digital or arbitrated axis sign (story 006), or the stick past `menu_stick_threshold` (story 020). Steps are emitted **always**: Input knows no modes, and Overworld simply ignores `nav_*`.
- **Release.** Releasing the direction clears its repeat state, and no further steps fire. `nav_*` never enter the held set, so no `released(nav_*)` is ever emitted.
- **The three cases (pinned).**
  - **Case 1** uses `repeat_interval = 0.05` (exactly 3 ticks at Δt = 1/60), so every due time lands exactly on a tick boundary — this is the boundary case. (The default `repeat_interval` 0.08 is 4.8 ticks, already a non-multiple, so it never exercises a due time exactly on a tick.)
  - **Case 2** is the default `repeat_interval` 0.08 — the AC's "not a multiple of Δt" case.
  - **Case 3 (hitch)** holds for 24 ticks, then calls `tick(0.25)`, which covers (0.40, 0.65] at the defaults: the steps due at 0.48, 0.56 and 0.64 fire on that tick, in k order. (A `tick(0.25)` straight after the press would contain no due time at the defaults — the first repeat is at 0.40 — so it would pass vacuously; it is kept only as a documented known negative.)
- Expected values are computed from cfg. Each case also runs with `NON_DEFAULT`. The GDD example "held 1.0 s → 9 steps" holds only at the defaults; compute it, don't hardcode it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 019: direction changes mid-repeat.
- Story 020: the stick menu threshold.
- Story 021: the `nav_*` pressed-only contract and UI re-injection.

---

## Files

- `src/input/input_resolver.gd` (repeat state per direction)
- `tests/unit/input/input_menu_repeat_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, fixes applied: time keeping pinned, 0.05 interval for the boundary case, non-vacuous hitch). The developer implements against these — do not invent new test cases during implementation.*

**AC-7** — steps fire on the first tick at or after `step_time(k)`, catch up in order, and stop on release.

```
Test: steps fire on the first tick at or after step_time(k)
Given: R with cfg (case 1: repeat_interval 0.05; case 2: DEFAULT; plus NON_DEFAULT); a recorder that stamps each nav_down with the current tick index n
When:  press S (n = 0), call tick(DT) N times where T = N × DT = 1.0 s (N = 60), then release S
Then:  for every k with step_time(k) <= T + EPS_T, exactly one nav_down at tick index ceil-by-tolerance(step_time(k) / DT); k = 0 at n = 0 (inside feed_event, before any tick); no other nav_down; at DEFAULT the count is 9 (computed, not literal)
Edge cases:
  - a step due exactly at T (case 1: choose N so T = step_time(k) exactly) counts
  - no step fires a tick early (assert the index of every step, not just the count)
```

```
Test: a hitch tick fires every due step, in order, never merged
Given: R with DEFAULT; S pressed; 24 × tick(DT)
When:  tick(0.25)
Then:  that single tick emits exactly the count of k with step_time(k) in (24 × DT, 24 × DT + 0.25] (3 at DEFAULT) as separate action_pressed(nav_down) entries
Edge cases:
  - with NON_DEFAULT the count is derived
  - a tick(0.25) immediately after the press emits 0 steps at DEFAULT (documented, so the vacuous case is a known negative and not the AC test)
```

```
Test: releasing stops further steps
Given: R; S held past 3 repeats
When:  release S, then tick 2 × repeat_delay
Then:  no nav_down after the release; no released(nav_down) at any point
Edge cases:
  - a key and a d-pad both hold down: releasing one keeps the repeat going (the held set)
  - the stick path is story 020's
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_menu_repeat_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-30; tests/unit/input 240/240, single-dir run, tag sin3)

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-004-digital-move-magnitude.md`
  - `production/epics/input-system/story-006-axis-arbitration.md`
- Unlocks:
  - `production/epics/input-system/story-010-no-pointer-move.md`
  - `production/epics/input-system/story-019-direction-change-restart.md`
  - `production/epics/input-system/story-020-menu-stick-threshold.md`
  - `production/epics/input-system/story-021-nav-pressed-only-reinjection.md`

## Completion Notes

*2026-10-30, implementation (autonomous run, tag sin3).*

- **Files**: `tests/unit/input/input_menu_repeat_test.gd` (story 018 section). No source change: the engine from story 020's run already met AC-7.
- **Tests**: schedule over T = 1.0 s for boundary (interval 0.05, last step due exactly at T), DEFAULT (non-multiple 0.08) and NON_DEFAULT, asserting every step's tick index and the closed-form count; hitch tick(0.25) after 24 ticks fires each due step as a separate entry (DEFAULT and NON_DEFAULT, non-vacuous); hitch straight after press as documented known negative; release stops steps, no released(nav_*); key + d-pad hold, releasing one keeps the schedule.
- **Deviations**: none.
