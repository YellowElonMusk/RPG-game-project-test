# Story 012: Exactly one hit-punch starts per beat, on that beat's impact frame

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-007`, `TR-presentation-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: The hit-punch is a whole-pixel `frustum_offset` shift, triggered at most once per beat on the beat's impact frame, with a big amplitude for a knockout or boss-actor beat, and no punch for a heal, Defend, Speak to the Manager, Viral Stunt or 0-damage Attack.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The punch itself is ADR-0005's `frustum_offset` mechanism (story 006); *when* it fires comes from ADR-0006's beat clocks (`BattleReplayController`, not yet built — a named dependency, not a blocker).

**Control Manifest Rules (this layer)**:
- Required: Battle camera: `frustum_offset` carries lens shift + hit-punch; it is the only per-frame change on the battle camera — source: ADR-0005
- Forbidden: Never set the battle camera's `h_offset`/`v_offset`, and never use a translation or rotation shake — the punch is `frustum_offset` only — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-10 [L]** (P-04) GIVEN a replay of N outcomes that lower HP, THEN exactly one punch starts per beat, on that beat's impact frame. A knockout beat, or a beat whose actor is the encounter's boss, uses the big amplitude. GIVEN a heal, Defend, Speak to the Manager, Viral Stunt or a 0-damage Attack, THEN no punch starts.

---

## Implementation Notes

*Derived from ADR-0005 Decision §6 and the beat-impact rule in ADR-0006's contract:*

- `DioramaStage.set_punch_offset_px(offset: Vector2i)` adds the punch to `frustum_offset` on the stage's battle camera; the stage owns no timer of its own for it.
- The owning mode fires the punch exactly on the impact frame the beat's clock reports (ADR-0006 §5), never from a tween or a sprite-animation callback.
- Amplitude selection (big vs. normal) is driven by whether the beat is a knockout or the encounter's boss, per the GDD's `hit_punch` table — this story tests the *gating* (one per beat, on impact, which outcome shapes trigger it at all), not the pixel formula itself (story 024).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013 (`production/epics/sprite-camera-presentation/story-013-punch-dropped-during-boss-takeover.md`): punches requested during a boss-takeover blend or hold
- Story 014 (`production/epics/sprite-camera-presentation/story-014-hit-punch-never-moves-actor-position.md`): actor world position during a punch
- Story 024 (`production/epics/sprite-camera-presentation/story-024-hit-punch-formula-is-pixel-exact.md`): the `hit_punch` offset formula's exact pixel values

---

## Files

- `src/presentation/diorama_stage.gd`
- `tests/unit/presentation/hit_punch_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/hit_punch_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, `production/epics/sprite-camera-presentation/story-006-battle-camera-lens-shift-only.md`, `BattleReplayController` (ADR-0006, no epic yet)
- Unlocks: `production/epics/sprite-camera-presentation/story-013-punch-dropped-during-boss-takeover.md`, `production/epics/sprite-camera-presentation/story-014-hit-punch-never-moves-actor-position.md`, `production/epics/sprite-camera-presentation/story-021-screen-shake-and-reduce-motion-scale-the-punch.md`, `production/epics/sprite-camera-presentation/story-024-hit-punch-formula-is-pixel-exact.md`
