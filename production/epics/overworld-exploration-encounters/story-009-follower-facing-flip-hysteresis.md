# Story 009: A follower's facing flips only after moving into the new direction, and copies the leader when idle

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: The `follower_trail` formula fixes a follower's facing as pointing from `pos_i` toward the trail point at `s_i − trail_sample_m`, with a flip hysteresis of `trail_sample_m` — the same anti-jitter principle ADR-0012 §2 applies to the leader's and symbols' displayed facing, applied here to followers.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure arc-length/direction math; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: "Facing is stored as a `Vector2`: the last non-zero `input_vec`, normalized. `CharacterSprite` maps it to the sprite set's facings." — source: ADR-0012 §2 (the same mapping layer followers' facing feeds)
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-5c [L] (`follower_trail`)** A follower's facing flips only after it has moved at least `trail_sample_m` in the new direction. When idle, followers copy the leader's facing.

---

## Implementation Notes

*Derived from the GDD `follower_trail` formula:*

"A follower faces from `pos_i` toward the trail point at `s_i − trail_sample_m`,
with a flip hysteresis of `trail_sample_m`." This keeps a follower from
flickering its facing every frame as it threads small wiggles in the trail —
the same jitter problem the leader's own facing snap and the symbol facing
hysteresis (stories 026–027) solve for their respective cases, but at a
different scale and mechanism (arc-length lookahead, not angular dead zone).

- Compute the facing direction from `pos_i` toward the trail sample at `s_i − trail_sample_m`; only commit a new facing once the follower has actually advanced `trail_sample_m` of arc length in that new direction, not on every frame the direction nominally changes.
- When the leader (and therefore the whole party) is not moving, followers hold no new trail samples to look ahead to — in that state, followers copy the leader's current facing directly rather than freezing on a stale trail-derived direction.
- Fixture: a scripted path with at least one direction change smaller and larger than the hysteresis window, confirming no flip below `trail_sample_m` of travel and a flip once it is exceeded; plus an idle-leader case confirming the copy-leader-facing fallback.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: position spacing along the trail.
- Story 026/027: the leader's and symbols' own facing hysteresis (a different formula, 45°+5° angular, not arc-length).

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/follower_trail_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/follower_trail_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-006-follower-trail-spacing-formula.md`
- Unlocks: None
