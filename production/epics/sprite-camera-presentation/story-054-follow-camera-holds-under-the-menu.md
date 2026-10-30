# Story 054: The follow camera holds still while the Menu is open

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-006`, `TR-presentation-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §6 gives the Overworld a perspective follow camera driven by the GDD's `follow_camera` formula; §7 ties every world clock to `mode_time`, which `ModeHost` freezes while the Menu is open, so the follow camera's own step must read `mode_time`, never `TIME` or an unconditional `_process` delta.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `ModeHost` disables processing under the Menu (ADR-0002, relied on here), so a camera driven from `mode_time`-scaled `delta` freezes for free; a camera that samples `get_viewport().size` or a raw node `_process(delta)` without going through the mode-time path would keep moving. No post-cutoff API is required beyond the already-probed perspective `Camera3D` path (§6).

**Control Manifest Rules (this layer)**:
- Required: `LightingProfile` and `PresentationConfig` are data; the follow camera's dead zone, tau, clamp and `dt_max` come from `PresentationConfig`, never literals (ADR-0005 §5)
- Required: `Core never imports Feature` — the follow camera and `DioramaStage` never reference Feature-layer types (ADR-0005 §7)
- Guardrail: On the Menu closing, the first frame's movement equals one formula step at `dt ≤ dt_max` — no catch-up jump

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [x] **AC-50 [L]** (P-07) (follow camera under the Menu) GIVEN the Overworld with the Menu open, WHEN the party anchor moves, THEN the camera is unchanged on every frame while the Menu is open. WHEN the Menu closes, THEN the first frame's movement equals one formula step with `dt ≤ dt_max`: no catch-up jump.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

The follow camera (§6) advances only from calls driven by mode time, exactly like `DioramaStage`'s ambient motion (§7) and the `PresentationDirector`'s own `mode_time` write (§4). While the Menu overlay is open, `ModeHost` stops calling the mode's `_process`, so the camera receives no `advance`/step call at all and its position is provably unchanged frame to frame. On close, the very next step must use the real elapsed `dt` (clamped to `dt_max`), applying exactly one formula step — never the accumulated time the Menu was open, which would read as a teleport-sized catch-up jump.
- The follow camera's step function takes an injected `dt`, never reads `Time` or an un-clamped node delta (testability, headless).
- No special-case "resume" branch is needed if the camera is simply not stepped while frozen; the correctness requirement is that nothing silently accumulates elapsed time behind it.
- This reuses `PresentationConfig`'s `dt_max` (shared with the replay controller's clamp, ADR-0006 §4) — the same constant, not a camera-local copy.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-055-resize-recomputes-punch-and-camera.md`: the camera's recomputation on a window resize
- The Overworld's own occupation-gradient profile selection (ADR-0012, no epic yet)

---

## Files

- `src/presentation/follow_camera.gd`
- `tests/unit/presentation/follow_camera_clamp_test.gd`, `tests/integration/presentation/follow_camera_overlay_hold_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/follow_camera_clamp_test.gd` + `tests/integration/presentation/follow_camera_overlay_hold_test.gd` — must exist and pass

**Status**: [x] Created and passing (see Completion Notes)

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md` (the follow camera's perspective-path formula, including `F_v_eff`, is probed in the spike)
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30. No new code: the camera has no clock of its own; only `OverworldView` steps it, and the view inherits the mode's process mode, which ModeHost disables under the Menu (ADR-0002 §5). The first frame after close is clamped by `ease_step()`'s `min(dt, dt_max)`. Tests: `test_first_step_after_freeze_is_one_dt_max_step` (unit) and `test_menu_freezes_camera_and_first_frame_after_is_one_dt_max_step` (assembled scene, 5 s first frame equals one `dt_max` step).

**Deviations**: test files differ from the planned `follow_camera_menu_freeze_test.gd`.
