# Story 046: no two actor slots share a view depth, in every shipped formation

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: Boot validation registers `PresentationValidators` for presentation content, and battle stages are validated on load (rule 10) — slot depths and formation data are part of the content this validation sweep must check before any battle can start.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Carries ADR-0005's general HIGH rendering risk through the slot-depth data this check validates (the same depths `SpriteProjection`'s upright-card projection consumes). The check itself is a pure data comparison, needing no engine verification.

**Control Manifest Rules (this layer)**:
- Required: "Boot validation registers `PresentationValidators`: ... battle stages validated on load" (Clocks and layering, ADR-0005 §7–§8, §11).
- Required: "`LightingProfile` and `PresentationConfig` are data (`.tres`). Every lighting/FOV/camera/texel/timing value comes from them, never literals" (Stages and lighting, ADR-0005 §3–§5) — slot depths are stage/formation data under this same rule, never hardcoded in a script.
- Forbidden: n/a — no Core Forbidden entry names formation/slot-depth authoring specifically.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-42 [L]** (P-07) (same-depth stagger) GIVEN every battle formation, THEN no two actor slots share a view depth, and the staggered stage still passes `battle_framing`.

---

## Implementation Notes

*Derived from ADR-0005 Decision §9 (Boot validation — "battle stages validated on load") and §2 (upright-card depth):*

- Every actor slot's view depth is the distance along the battle camera's forward axis to that slot's foot anchor — because occlusion is exact per-pixel with no `DEPTH` write (§2), two slots sharing a depth would mean two actors rendering with ambiguous (effectively coincident) depth ordering, which this validator must reject as a content error, named per formation.
- "Staggered" means depths are deliberately offset per slot to guarantee uniqueness (the GDD's stagger rule) — this story's test fixture includes at least one formation that would collide without the stagger, to prove the check actually catches a real collision, not just pass trivially-already-distinct data.
- `battle_framing` (referenced in ADR-0005 §6 Risks, "Step 1 re-measures the lens shift against `battle_framing`'s `y_h`") is the existing framing validator that confirms every slot's quad lies inside the camera's view — this story must re-run it against the staggered depths to confirm the stagger itself doesn't push any slot out of frame, since changing depth changes a sprite's projected screen position under perspective.
- This validator is boot-time, content-only: it runs over every shipped formation's data, not over a live scene — no `CharacterSprite` instantiation is required to test it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-047-occlusion-and-visibility-pass-the-threshold.md`: whether a non-colliding but poorly staggered formation still lets each slot's silhouette stay sufficiently visible (a different, visibility-share concern).
- `story-050-camera-holds-every-slot-in-view-at-every-aspect.md`: aspect-ratio framing (this story only needs the camera's default aspect for `battle_framing`).
- Authoring the formation data itself for every shipped battle (content production).

---

## Files

- `data/presentation/presentation_validators.gd`
- `tests/unit/presentation/slot_depth_collision_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/slot_depth_collision_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created and passing -- `tests/unit/presentation/slot_depth_collision_test.gd` (presentation suite 99/99, 2026-10-30)

---

## Dependencies

- Depends on: `story-001-windowed-engine-spike.md` (settles slot depths and `battle_framing`'s measurement); every shipped battle formation authored
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30 (tag scp3)

BattleStage.slot_depth(i) = base depth + i * slot_depth_step (the GDD stagger); BattleFraming.depth_collisions() reports equal depths and validate() fails them by stage name. PresentationValidators loads and validates every shipped stage. Deviation: the validator is src/presentation/presentation_validators.gd, not data/presentation/presentation_validators.gd (scripts belong in the code root). Not yet registered with ContentBootstrap (TODO, same blocker as PresentationConfig.validate).

**Files**: src/presentation/presentation_validators.gd (new), src/presentation/battle_framing.gd, src/presentation/battle_stage.gd, tests/unit/presentation/slot_depth_collision_test.gd
