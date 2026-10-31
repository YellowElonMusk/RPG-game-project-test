# Story 010: Opening the Menu freezes every presentation clock, beat, punch and particle

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31) -- [I] `tests/integration/presentation/menu_freeze_test.gd` 5/5; [C] live capture PASS (open diff 0 px, control 66,921 px); full suite 1890/1890 exit 0; lead sign-off owed
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: The world freezes under the Menu: `mode_time` stops, particles are paused by the stage on `overlay_opened(MENU)`, and no shader reads `TIME`, so a frozen frame stays bit-identical.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Depends on ADR-0002's `ModeHost` disable (Core) plus ADR-0005's own particle pause and `mode_time` sink; the `[C]` half of this AC is Pending until story 002's capture tool exists and is proven on a moving-particle fixture.

**Control Manifest Rules (this layer)**:
- Required: World shaders (the sky card's clouds included) read `mode_time` only, never `TIME` — source: ADR-0005
- Required: `PresentationDirector`, on `overlay_opened(MENU)` / `overlay_closed(MENU)`, calls `stage.set_ambient_paused(true/false)` — source: ADR-0005
- Forbidden: No world shader may ever read `TIME`; this covers shader files, embedded shader code and visual-shader Time nodes — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-8 [I]+[C]** (P-01, P-08) Three cases, each frozen by opening the Menu: (a) mid-wind-up of a beat, (b) on the third frame of a running hit-punch, (c) mid-blend of a first-encounter boss takeover.
  - **[I]:** over 300 frames with the Menu open, the probe reads unchanged values for the `mode_time` global, every lighting parameter, the camera's lens shift, every sprite's frame, and the replay's state and clocks, and no beat, hold, number or sound event fires. On the frame after the Menu closes, each value has moved by no more than one `dt_max` step of its formula. Every particle node in the mode scene reports it is not processing, and none under `ModeHost` is set to always process.
  - **[C], live, with a control:** two frames of the running game's main viewport, case (a) on a stage with a moving-particle fixture, grabbed 1 s of real time apart with the Menu open, are pixel-identical in the world layer. The same two grabs with the Menu closed differ, so the check can fail. Pending: the capture tool.

---

## Implementation Notes

*Derived from ADR-0005 Decision §4 and §7:*

- `PresentationDirector` writes `mode_time` from `machine.mode_time` every frame, which stops under the Menu (ADR-0002).
- On `overlay_opened(MENU)` / `overlay_closed(MENU)` the Director calls `stage.set_ambient_paused(true/false)`; Dialogue and the Defeat Prompt do **not** pause ambience (story 011 covers that boundary).
- Node-driven ambient motion already freezes because ADR-0002 disables `ModeHost` processing; particles are paused explicitly by the stage on the Menu overlay.
- The `[C]` clause is Pending until story 002's capture tool exists; this story's `[I]` half can close independently, but the full AC needs both.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011 (`production/epics/sprite-camera-presentation/story-011-dialogue-and-defeat-prompt-keep-animation-running.md`): the Dialogue/Defeat-Prompt case, which must keep animating, not freeze

---

## Files

- `src/presentation/presentation_director.gd`
- `src/presentation/diorama_stage.gd`
- `src/presentation/character_sprite.gd`
- `tests/integration/presentation/menu_freeze_test.gd`
- `production/qa/evidence/menu-freeze-stops-every-presentation-clock/`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: a retained screenshot in `production/qa/evidence/menu-freeze-stops-every-presentation-clock/` + sign-off in `production/qa/evidence/menu-freeze-stops-every-presentation-clock-evidence.md`

**Status**: [x] `production/qa/evidence/menu-freeze-stops-every-presentation-clock/` (open_a/b, closed_a/b, diff masks, measurements.json, stamp.txt) + `production/qa/evidence/menu-freeze-stops-every-presentation-clock-evidence.md`; lead sign-off owed

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, `production/epics/sprite-camera-presentation/story-002-capture-tool.md`, `production/epics/sprite-camera-presentation/story-008-mode-entry-applies-lighting-before-reveal.md`
- Unlocks: None
