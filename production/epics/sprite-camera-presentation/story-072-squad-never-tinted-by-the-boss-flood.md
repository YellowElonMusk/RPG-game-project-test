# Story 072: The squad is never tinted by a faction's boss flood

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-024`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: Rule 11 (TR-presentation-024) requires faction colour only on the sky, set and fill during a boss takeover, never on actors; §2's actors use `ambient_light_disabled` and are lit only by `KeyLight` and tagged practicals, so the squad's own colour must be identical, within tolerance, between a faction's boss takeover and the same stage's plain Battle capture.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: This is a capture-measured negative check on the same actor-lighting isolation verified for story 052 (practicals) — here against the boss takeover's `boss_<faction>` profile's set/fill tint specifically, rather than a practical light.

**Control Manifest Rules (this layer)**:
- Required: Actors use `render_mode ambient_light_disabled`; only lights whose cull mask includes `ACTORS` light them — `SetLight`/`FillLight` never do (ADR-0005 §2–§3)
- Required: Faction colour appears only on the sky, set and fill during a boss takeover; never on actors (ADR-0005 §2, §3, §5)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-67 [C]** (P-09) (the squad is never tinted; Pending: capture tool) On each faction's boss takeover capture and the same stage's Battle capture, each squad member's actor pixels differ by at most ΔE 3 on average and ΔE 6 at the 95th percentile.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

The capture tool's ID pass isolates each squad member's actor pixels on a `boss_<faction>` takeover capture and on the same stage's plain `battle` capture, then diffs them in ΔE: the mean must stay at or below 3, and the 95th percentile at or below 6, for every faction.
- Both factions' boss profiles must be captured against the same battle stage, so the only variable between the two captures is the lighting profile, not stage geometry or camera.
- A failure here means `SetLight`/`FillLight` (which carry the faction tint, §3) are reaching an actor's cull mask, or a practical tagged `actor_lighting` is itself faction-coloured — both are data/placement bugs in the shipped boss profiles, not a change to the occlusion or lighting mechanism.
- This reuses the capture tool's existing ID pass and shadow mask (story 002, §13); no new capture pass is introduced.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-057-ui-never-tinted-by-the-world.md`: the same faction-colour rule, applied to the UI layer instead of actors
- `story-052-no-emissive-behind-actor.md`: practicals shining through an actor's silhouette, a different failure mode

---

## Files

- *(capture-only; no production file changes expected if the light rig is already correctly culled)*
- `production/qa/evidence/squad-never-tinted/`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- A retained capture-tool output in `production/qa/evidence/squad-never-tinted/`
- Sign-off in `production/qa/evidence/squad-never-tinted-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-002-capture-tool.md` (the capture tool; this is a [C] story); the boss stages (no epic yet, needed for both factions' takeover captures)
- Unlocks: None
