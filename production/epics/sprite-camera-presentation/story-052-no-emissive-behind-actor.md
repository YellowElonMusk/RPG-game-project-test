# Story 052: No emissive source bleeds through an actor's silhouette

> **Epic**: Sprite & Camera Presentation
> **Status**: Partial, blocked on Title/Camp 3D scenes (2026-10-31): AC-48 check built and PASS on the 6 capturable AC-32 states (battle, both boss takeovers, Victory peak, Defeat, Overworld) with the behind/beside/actor_lighting controls behaving; Title and Camp have no 3D scene to capture yet; lead sign-off pending
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-003`, `TR-presentation-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §2 gives each `CharacterSprite` an exact, per-pixel card depth with no `DEPTH` write, so a practical placed behind an actor's upright card must occlude correctly against it; §3 lets a stage tag a practical `actor_lighting` only when it is meant to light actors, never to shine through them.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The clip-space quad's depth is exact per pixel because the card is planar and the rasterizer interpolates perspective-correctly (verified item 10, 2026-10-22), so a correctly authored practical already occludes against it with early-z on. This story is a capture-measured check that the shipped data and placement honour that guarantee — it does not change the occlusion mechanism.

**Control Manifest Rules (this layer)**:
- Required: Actors use `render_mode ambient_light_disabled`; only lights whose cull mask includes `ACTORS` light them (ADR-0005 §1–§2)
- Required: A practical that also lights actors adds `ACTORS` to its cull mask and is tagged `actor_lighting` (ADR-0005 §3)
- Forbidden: Compositing separate `SubViewport`s for set and actors — pipeline risk, doubled passes (ADR-0005)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-48 [C]** (P-09, P-10) (emissive behind an actor; Pending: capture tool) On every AC-32 capture, rendered once more with the actors hidden, no emissive pixel lies inside any actor's silhouette. Emissive pixels beside an actor are allowed, so a Camp fire beside the squad passes.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

This is a capture-measured negative check on top of AC-32's existing emissive captures (§3 sky card / practicals, §2 card depth). The capture tool (story 002) re-renders each AC-32 scene a second time with every `CharacterSprite` hidden, then diffs the two ID-pass renders: any emissive pixel that falls inside the first render's actor silhouette but is not itself tagged as actor lighting is a failure. No production code changes are implied if the existing light-rig and occlusion rules (ADR-0005 §2–§3) are already correctly authored; a failure here means a practical's placement or cull mask is wrong in the shipped data, not that the mechanism needs to change.
- The check only runs scenes AC-32 already captures — no new stage fixtures.
- A practical beside an actor (the Camp fire) is explicitly allowed to pass; only pixels inside the actor's own silhouette are checked.
- A regression here is a data fix (practical placement, `actor_lighting` tagging), not an ADR-0005 mechanism change.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-002-capture-tool.md` (writer A): builds the capture tool and its ID pass this story depends on
- The light rig and card-depth mechanism themselves (ADR-0005 §2–§3) — built by the earlier `src/presentation/` stories, not this one

---

## Files

- *(capture-only; no production file changes if the shipped data already passes)*
- `production/qa/evidence/no-emissive-behind-actor/` (retained capture pass/fail output)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- A retained screenshot/capture-tool output in `production/qa/evidence/no-emissive-behind-actor/`
- Sign-off in `production/qa/evidence/no-emissive-behind-actor-evidence.md`

**Status**: [~] `production/qa/evidence/no-emissive-behind-actor/` (tool `tools/capture/emissive_bleed_capture.gd`, exit 0: bleed 0 px in all 6 captured states; negative control (emissive quad behind Squad2) FAILS with 5079 bleed px; beside control PASSES with 30625 emissive px on screen; actor_lighting-tagged source exempt) + `production/qa/evidence/no-emissive-behind-actor-evidence.md` (lead sign-off pending); `tests/unit/presentation/emissive_bleed_check_test.gd` (16 cases) passes; full suite 1955/1955, exit 0 (2026-10-31). Open: Title and Camp captures once those modes have 3D scenes

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-002-capture-tool.md` (the capture tool; this is a [C] story)
- Unlocks: None
