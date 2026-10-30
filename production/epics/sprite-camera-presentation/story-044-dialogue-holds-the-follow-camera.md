# Story 044: the follow camera holds its position while Dialogue is open

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: The Overworld's `FollowCamera` is a perspective camera moving position only; `PresentationDirector` pauses a stage's ambient motion on `overlay_opened(MENU)`/`overlay_closed(MENU)`, but Dialogue and the Defeat Prompt do not pause ambience — the camera-hold for Dialogue is a distinct behaviour from the Menu's full freeze.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Carries ADR-0005's general HIGH rendering risk and the still-to-verify perspective follow-camera path (Step 1, 16:10 and 4:3). This story's hold behaviour is a position-update gate, not new camera projection math, so it adds no further engine-verification burden beyond `story-031`'s.

**Control Manifest Rules (this layer)**:
- Required: "**Overworld:** a perspective follow camera (`FollowCamera`) at a fixed yaw and pitch, moving position only" (Cameras, ADR-0005 §6).
- Required: "`PresentationDirector` calls `stage.set_ambient_paused(true/false)` on `overlay_opened(MENU)`/`overlay_closed(MENU)`. Dialogue and the Defeat Prompt don't pause ambience" (Stages and lighting, ADR-0005 §3–§5) — the explicit contrast this story's hold must not be confused with: the camera holds for Dialogue, but ambient motion (clouds, idle sprites) keeps running.
- Forbidden: "Never add a second `Camera3D` or `WorldEnvironment` to a mode scene that already has a `DioramaStage`" (ADR-0005).

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [x] **AC-40 [L]** (P-07) (overlay camera hold) GIVEN Dialogue open in the Overworld, WHEN the party anchor moves, THEN the follow camera's position is unchanged until the Dialogue closes.

---

## Implementation Notes

*Derived from ADR-0005 Decision §6 (Cameras — Overworld) and §4 (overlay handling):*

- This is a **position hold**, not a pause of the whole stage: unlike the Menu (which freezes `mode_time` itself via `ModeHost`, ADR-0002 §5), Dialogue leaves ambient motion running (§4: "Dialogue and the Defeat Prompt don't pause ambience") — only the follow camera's own position update must stop while Dialogue is open.
- The hold is driven by Dialogue's own overlay-opened/closed announcement (the Overworld mode listens for it directly, since `PresentationDirector`'s `set_ambient_paused` hook is Menu-specific per §4) — the follow camera must stop recomputing its dead-zone/clamp position from the party anchor the instant Dialogue opens, and resume tracking from its held position (not snap) the instant it closes.
- "Until the Dialogue closes" implies the test must move the party anchor *during* the held window and assert the camera's position is byte-identical across every frame of that window, then assert tracking resumes normally afterward — a test that only checks the position immediately before/after Dialogue would miss a camera that drifted mid-hold.
- This story's camera is the same `FollowCamera` instance `story-031` tests for warp-snap and map-edge clamping — this story adds the Dialogue-hold gate on top of that existing position-update logic, it does not reimplement the clamp or the dead zone.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-031-camera-snaps-on-warp-and-clamps-at-map-edges.md`: the warp-snap and ground-footprint clamp themselves.
- Dialogue's own overlay lifecycle and announcement plumbing (the Overworld/Dialogue epic, ADR-0012, no epic yet).
- `story-048-reduce-motion-zeroes-ambient-motion.md`: ambient motion's Reduce Motion behaviour (unrelated — this story's hold applies regardless of that setting).

---

## Files

- `src/presentation/follow_camera.gd`
- `src/overworld/overworld_mode.gd` (`is_dialogue_open()`), `src/overworld/overworld_view.gd`
- `tests/unit/presentation/follow_camera_clamp_test.gd`, `tests/integration/presentation/follow_camera_overlay_hold_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/follow_camera_clamp_test.gd` + `tests/integration/presentation/follow_camera_overlay_hold_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created and passing (see Completion Notes)

---

## Dependencies

- Depends on: `story-031-camera-snaps-on-warp-and-clamps-at-map-edges.md`; the Overworld (ADR-0012, no epic yet — owns the party anchor and Dialogue's overlay announcement)
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30. `FollowCamera.held` makes `advance()` a no-op; `OverworldView._present()` sets it from `OverworldMode.is_dialogue_open()` (Dialogue anywhere in the overlay stack) every frame, so tracking resumes from the held position (one formula step, never a snap) on the first frame after close. Tests: `test_held_camera_is_unchanged_then_resumes_from_held_position` (unit) and `test_dialogue_holds_camera_until_it_closes` (assembled scene, 30 frames held, then one step); seen failing with the hold line removed.

**Deviations**: the hold lives in `follow_camera.gd`/`overworld_view.gd`, not `sprite_projection.gd`; the test file names differ from the planned `follow_camera_dialogue_hold_test.gd`.
