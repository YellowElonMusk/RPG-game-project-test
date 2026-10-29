# Story 007: Followers snap into formation on map entry, teleport, redirect and battle thaw

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0002: Game State & Scene Flow
**ADR Decision Summary**: ADR-0012 §4/§6 fixes the four moments that reset the party's position outside normal walking — map change, a teleport, a checkpoint `redirect` (via `request_in_mode_fade`), and a battle thaw (`on_thawed`) — and in every one, "followers re-form" as part of that event, not as an independent per-frame behaviour. ADR-0002 is what actually drives three of the four triggers (the fade, the thaw).
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0002's own Knowledge Risk is HIGH because none of the Core APIs it leans on (`Node.add_child`/`remove_child`, `process_mode`, `PackedScene.instantiate()`) is covered by `docs/engine-reference/godot/` yet, despite being fundamental — verify before trusting any claim about transition timing.

**Control Manifest Rules (this layer)**:
- Required: "A failed checkpoint's redirect closes the Dialogue and then calls `machine.request_in_mode_fade(callback)`; the callback places the leader at the return marker, snaps the camera and followers, and writes `WorldState` itself" — source: ADR-0012 §2, §6
- Required: "Two-step thaw: all state changes in `on_thawed` under the wipe... Noticing/Chasing → Returning after every transition" — source: ADR-0012 §5

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-5a [L] (R2, Edge Cases)** GIVEN a map entry, a teleport, a checkpoint redirect or a battle thaw, THEN on that frame the trail is cleared and followers sit at spacing behind the leader, opposite its facing, on walkable cells. When a wall blocks, the remaining followers share the last walkable point.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines, GDD rule 2 and Edge Cases:*

Edge Cases is explicit about this exact AC: "If the map changes, or the leader
is teleported or redirected: the trail is cleared and the followers snap into
formation. The trail is filled with points behind the leader (opposite its
facing) along walkable cells. If a wall blocks, the remaining followers stack
at the last walkable point." Rule 7 adds the fourth trigger: "Both. Followers
re-form behind the leader" (after `on_thawed`, for both Victory and Fled).

- All four triggers funnel into the same reset routine: clear the trail buffer, then synthesize `n_f` points walking backward from the leader's position opposite `party_facing`, each `follower_spacing_m` apart, over **walkable** cells only.
- "On walkable cells" uses the leader's blocked mask (baked walls + runtime-blocked), not the symbol mask — followers are not symbol-legal-constrained, since `SAFE` cells are perfectly fine for a follower to stand on.
- The wall-blocked case: when the synthesized backward walk hits a non-walkable cell before placing every follower, every remaining follower shares that last walkable point (no follower is ever placed off the walk grid).
- Fixture coverage: a map-entry placement, a scripted teleport, a checkpoint redirect (via the same-instance in-mode fade, ADR-0002 §11) and a battle thaw (`on_thawed`) — all four must reset identically, and the test harness's stub Game State is what exercises the redirect/thaw triggers headlessly.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: steady-state trail formula while walking normally.
- Story 013/014: the overlay/transition lockout logic a redirect's Dialogue goes through before the fade.
- Game State's own transition and thaw machinery (`production/epics/game-state-scene-flow/`, epic done) — this story only consumes its signals.

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/follower_snap_on_reset_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/follower_snap_on_reset_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (6 cases); evidence `production/qa/evidence/story-007-follower-snap/`

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-006-follower-trail-spacing-formula.md`; Game State mode-transition/thaw machinery (`production/epics/game-state-scene-flow/`, epic done)
- Unlocks: None
