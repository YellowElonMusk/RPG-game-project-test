# Story 041: every boss stage frames its faction's colorblind-safe shape in view

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-024`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: Faction colour appears only on the sky, set and fill during that faction's boss takeover (and future occupation stages), never on actors, neutral states, fades or UI; every boss stage frames a tagged faction shape — the colorblind-accessibility channel independent of hue.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Carries ADR-0005's general HIGH rendering risk; the check itself is a scene-graph query (node tags and camera-frustum bounds test) against the battle camera's fixed `PROJECTION_FRUSTUM`, which needs no further engine verification beyond what §6 already establishes.

**Control Manifest Rules (this layer)**:
- Required: "`SkyCard`... draws the GDD's stars... tagged `star` in the ID pass" (Stages and lighting, ADR-0005 §3–§5) — the same ID-pass tagging convention this story's faction-shape node uses.
- Forbidden: "Never use `AreaLight3D`, HDR output, FXAA, SMAA, TAA, an upscaler, or a render scale below 1.0 without an amendment to this ADR" — not directly applicable; the closest relevant Forbidden rule is the general "faction colour only on sky, set and fill" constraint (quoted in Implementation Notes from the TR itself, since no Core Forbidden entry names it verbatim).
- Guardrail: n/a — a scene-graph presence/bounds check carries no frame-time or draw-call cost worth budgeting.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-37 [I]** (P-07) (colorblind shape, rule 11) GIVEN each boss stage, THEN at least one node tagged as that faction's shape exists, and its bounds lie inside the battle camera's view on every frame of the takeover blend and hold.

---

## Implementation Notes

*Derived from the GDD's rule 11 (carried by TR-presentation-024) and ADR-0005 §6 (the battle camera's fixed frustum):*

- Every boss stage must contain at least one node tagged with its faction's shape identifier (the same tagging convention the `SkyCard` uses for `sky`/`star` in the capture tool's ID pass, §3) — this story's test queries the scene tree for that tag per boss stage, not for any particular node type, so the shape can be authored as a decal, a mesh, or a card without constraining art.
- "Inside the battle camera's view on every frame of the takeover blend and hold" is checked against `SpriteProjection`'s `CameraState` (built via `Projection.create_frustum_aspect()`, never `Camera3D.get_camera_projection()`, per ADR-0005 §6) — the same projection math every other camera-bounds AC in this epic uses, so this story reuses that helper rather than writing a second frustum-culling implementation.
- Because the battle camera never moves, rotates, zooms or changes FOV in a fight (ADR-0005 §6), "every frame of the blend and hold" reduces to one static bounds check against one fixed frustum — the shape's own screen position does not change across the takeover, only the lighting around it does.
- This is the mechanical half of accessibility (shape existence and visibility); the "is it actually readable as distinct from another faction's shape" judgement is a design/art concern outside this engineering story's scope.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-038-boss-takeover-faction-parity.md`: cross-checks this AC's result against its own capture (consumes this story's pass/fail, does not re-implement it).
- Authoring the actual faction-shape art/mesh (art production, not engineering).
- The sky/set/fill faction-colour restriction itself on actors (already structurally guaranteed by ADR-0005 §2's `ambient_light_disabled` and cull masks — not re-tested here).

---

## Files

- `src/presentation/diorama_stage.gd`
- `src/presentation/sprite_projection.gd`
- `tests/integration/presentation/faction_shape_in_view_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/presentation/faction_shape_in_view_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: boss stages (content, not yet authored — this story needs at least one authored boss stage per MVP faction to run against); `story-001-*` (settles `battle_fov` and the frustum the shape must land inside)
- Unlocks: None
