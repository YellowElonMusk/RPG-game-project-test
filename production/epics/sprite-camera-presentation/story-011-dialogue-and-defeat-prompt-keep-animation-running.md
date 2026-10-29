# Story 011: Sprite animation keeps advancing while Dialogue or the Defeat Prompt is open

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: Only `overlay_opened(MENU)`/`overlay_closed(MENU)` pause a stage's ambience; Dialogue and the Defeat Prompt do not pause it, so ambient sprite animation keeps advancing on mode time while either is open.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; relies on `CharacterSprite.step_ambient(mode_dt)` continuing to receive non-zero `mode_dt` while Dialogue or the Defeat Prompt overlay is open (neither is `MENU`).

**Control Manifest Rules (this layer)**:
- Required: `PresentationDirector`'s `overlay_opened(MENU)` / `overlay_closed(MENU)` pause ambience; Dialogue and the Defeat Prompt don't pause ambience — source: ADR-0005
- Forbidden: Never pause `set_ambient_paused` for any overlay other than the Menu — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-9 [L]** (P-06) GIVEN Dialogue or the Defeat Prompt open, WHEN mode time advances, THEN sprite animation advances.

---

## Implementation Notes

*Derived from ADR-0005 Decision §4 and §1:*

- The Director's `set_ambient_paused(true/false)` call is wired only to `overlay_opened(MENU)`/`overlay_closed(MENU)`; Dialogue and the Defeat Prompt are different overlays and never trigger it.
- Ambient frames (idle, walk) are stepped by `CharacterSprite.step_ambient(mode_dt)` on mode time in its own `_process`; as long as `GameStateMachine.mode_time` advances, ambient stepping advances with it, regardless of which non-Menu overlay is open.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010 (`production/epics/sprite-camera-presentation/story-010-menu-freeze-stops-every-presentation-clock.md`): the Menu's own freeze behaviour

---

## Files

- `src/presentation/character_sprite.gd`
- `tests/unit/presentation/character_sprite_ambient_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/character_sprite_ambient_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, `production/epics/sprite-camera-presentation/story-005-no-mirror-animations-use-authored-art.md`
- Unlocks: None
