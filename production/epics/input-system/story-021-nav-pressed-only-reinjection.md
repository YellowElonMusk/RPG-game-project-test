# Story 021: Each menu step is exactly one `nav_*` `pressed` (never `held` or `released`), re-injected by the UI as the matching `ui_*` `InputEventAction`

> **Epic**: Input System
> **Status**: Blocked — BLOCKED: needs the UI Framework epic — UiNavigator re-injection half, ADR-0008 §3
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-008`, `TR-input-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§5 re-inject, bounded; §8); ADR-0008: UI Framework (§3, `UiNavigator`)
**ADR Decision Summary**: Menu steps leave Input only as `nav_*` `pressed` events (never held, never released). After routing, the UI's `UiNavigator` re-injects each as an atomic `ui_*` `InputEventAction` press-then-release pair, only when focus is inside the receiver's subtree, so native `Control` focus and AccessKit see real focus changes.
**ADR Version**: ADR-0003 2026-10-21; ADR-0008 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Re-injection through `Input.parse_input_event()` with an `InputEventAction` is verified on 4.7.2 (spike item 2), but "the `pressed` emission lags a frame" (ADR-0003 Risks). 4.6 dual focus applies to the `Control` side.

**Control Manifest Rules (this layer)**:
- Required: "**Re-injection into `ui_*` actions fires only when focus is inside the receiver's own subtree, and only as an atomic press-then-release pair.** Routed releases are never mirrored"
- Required: "**`InputSystem` node is the only script that touches engine input** (`_input`, `Input.*`, `InputMap` mutation). One named exception: `src/ui/ui_navigator.gd` (`UiNavigator`) may call `Input.parse_input_event()` for `ui_*` actions"
- Required: "**`action_pressed`/`action_released` fire on edges; `action_held` fires every `tick` while held.** `nav_*` are derived actions, never bound directly"
- Forbidden: "**Never build a fully custom focus system** in place of native `Control` focus — throws away AccessKit (4.5+) integration"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-25** Each menu step is emitted as exactly one `nav_up`/`nav_down`/`nav_left`/`nav_right` with `pressed` only (never `held` or `released`), and the UI re-injects it as the matching `ui_*` `InputEventAction` (spy on the injected event).

---

## Implementation Notes

*Derived from ADR-0003 §5, §8 and ADR-0008 §3:*

- **Why Blocked.** The AC's second clause ("the UI re-injects it as the matching `ui_*` `InputEventAction` (spy on the injected event)") verifies `UiNavigator.route()` (`src/ui/ui_navigator.gd`, ADR-0008 §3). That is UI Framework code, outside this epic's directories (coordination rule 5), and no epic in `production/epics/` owns it yet. **Unblock** by creating the ui-framework epic and making this story depend on its `UiNavigator` story. The done gate then becomes "resolver half passes, and the UiNavigator spy test passes".
- **Resolver half (can be written now).** `nav_*` are never put in the held set, so `tick()` never emits `action_held(nav_*)` and nothing ever emits `action_released(nav_*)`. Assert over a long hold with repeat: the count of `pressed(nav_down)` equals the step count from story 018, and the counts of `held(nav_*)` and `released(nav_*)` are 0.
- **UI half (ADR-0008 §3, owned by the ui-framework epic).** The mapping is `nav_up/down/left/right` → `ui_up/down/left/right`. The helper injects only if `receiver.get_viewport().gui_get_focus_owner()` is the receiver or its descendant. It injects an atomic pair, `pressed = true` then `pressed = false`, and never mirrors a routed release. The spy observes the `InputEventAction` passed to `Input.parse_input_event()`. Inject the call through a `Callable` seam, so the unit test never touches global `Input`.
- **Timing.** Tests of re-injected navigation must assert on the `Control` signal, or await at least two frames.
- **The `ui_*` strip.** The strip that makes re-injection the only path is in story 025 (shell).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- UI Framework epic: `UiNavigator.route()` and its spy test (`tests/unit/ui/ui_navigator_test.gd`).
- Story 025: stripping `ui_*` device bindings.
- Story 018: the step schedule.

---

## Files

- `tests/unit/input/input_nav_actions_test.gd` (resolver half: no `held`/`released` for `nav_*`)
- (outside this epic) `src/ui/ui_navigator.gd` and `tests/unit/ui/ui_navigator_test.gd` — owned by the ui-framework epic

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS: no AC change; status stays Blocked; the UI half is written as the dependent ui-framework story's test). The developer implements against these — do not invent new test cases during implementation.*

**AC-25** — `nav_*` are pressed-only, and the UI re-injects them as `ui_*` pairs.

```
Test (resolver half): nav steps are pressed-only
Given: R with DEFAULT
When:  hold S, D, W and A in turn for 1.0 s each, with tick(DT)
Then:  count(pressed(nav_x)) == story 018's computed step count per direction; count(held(nav_*)) == 0; count(released(nav_*)) == 0
Edge cases:
  - the stick path gives the same result
  - focus loss during a hold emits no released(nav_*)
```

```
Test (UI half, owned by the ui-framework epic): UiNavigator re-injects nav as an atomic ui_* pair
Given: UiNavigator with its parse-input Callable seam replaced by a spy; a receiver Control that owns focus
When:  route(&"nav_down") (then nav_up/left/right)
Then:  the spy receives exactly 2 InputEventActions: action == &"ui_down", pressed = true, then pressed = false
Edge cases:
  - focus outside the receiver's subtree gives 0 injections
  - a routed release is never mirrored
  - a scene-level check asserts on the Control's focus_entered, or awaits 2 frames
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_nav_actions_test.gd` — must exist and pass. Gate level: BLOCKING.
- Logic (ui-framework epic): `tests/unit/ui/ui_navigator_test.gd` — must exist and pass before this story closes.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-018-menu-repeat-timing.md`
  - the ui-framework epic's `UiNavigator` story (epic not yet created)
- Unlocks: None
