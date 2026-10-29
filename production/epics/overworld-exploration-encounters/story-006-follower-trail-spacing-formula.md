# Story 006: Followers hold formation on the leader's recorded trail at fixed spacing

> **Epic**: Overworld Exploration & Encounters
> **Status**: Implemented, awaiting /story-done
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017` (followers are cosmetic trail sprites) — best match; no TR line names the trail formula's own math
**Requirement note**: `TR-overworld-017`'s "followers are cosmetic trail sprites" clause is the closest TR text; the `follower_trail` formula itself has no dedicated TR line.
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: Followers are cosmetic `CharacterSprite`s with no logic of their own; the GDD's `follower_trail` formula (not ADR-0012 text directly, but the mechanism ADR-0012 §2 Facing/position rules assume) replays the leader's recorded path at `follower_spacing_m` arc-length intervals.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure arc-length math over recorded `Vector2` points; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: "Positions are ground-plane `Vector2`s (x east, y south), rendered at `Vector3(p.x, 0, p.y)`; logic never reads a 3D transform back" — source: ADR-0012 §1
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-4 [L] (R2, `follower_trail`)** GIVEN 3 followers and a scripted path with a 90° corner, at `dt` values of 1/60 s and `dt_max`:
  - every frame, follower `i` lies on the recorded trail at arc length `i · follower_spacing_m` (± `trail_sample_m` / 2);
  - no follower is further than `trail_sample_m` / 2 from the leader's walked polyline;
  - the buffer length equals `N_buf`;
  - when the leader stops, every follower stops on the same frame.

---

## Implementation Notes

*Derived from the GDD `follower_trail` formula (Formulas) and rule 2:*

The formula: each frame, walk the leader's segment `[p_prev, p_leader]` and
append a point every `trail_sample_m` of arc length; `pos_i` is the point at
arc length `s_i = i · follower_spacing_m` back along `[p_leader, trail
newest→oldest]`; `N_buf = ⌈n_f · follower_spacing_m / trail_sample_m − ε⌉ + 2`.

- `follower_spacing_m` (0.7–1.1 m, default 0.9) is the arc-length gap between neighbours; `trail_sample_m` (0.05–0.25 m, default 0.15) is the distance between recorded trail points. Both are `OverworldConfig` knobs, never literals.
- Sub-sample inside each frame's segment so spacing never exceeds `trail_sample_m`, however long the frame is — this is what keeps the ± `trail_sample_m`/2 bound true at both `dt = 1/60 s` and `dt = dt_max`.
- Followers move with the leader's **travelled distance**, not with time: "they stop when the leader stops and never bunch up" — so the fourth bullet (same-frame stop) falls directly out of the arc-length-driven lookup, not a separate rule.
- Worked example from the Formulas section: spacing 0.9 m, sample 0.15 m, 3 followers gives `N_buf = 20`; follower 3 trails 2.7 m behind; round a 90° corner and follower 2 (1.8 m back) is still on the leader's path; a 0.10 s frame moves the leader 0.35 m and appends two points, 0.15 m apart. Use this as a cross-check, not the only fixture.
- Run the test once with a non-default `follower_spacing_m`/`trail_sample_m` pair, per the harness's "computed from config" rule.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: trail reset on map entry, teleport, redirect and thaw.
- Story 008: party of one and mid-visit recruit join.
- Story 009: follower facing flip hysteresis.

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/overworld/follower_trail.gd` (new -- the pure, testable trail unit the build brief asked for)
- `src/overworld/overworld_config.gd` (`follower_spacing_m`, `trail_sample_m`)
- `tests/unit/overworld/follower_trail_test.gd`

---

## Completion Notes

- `FollowerTrail` (new `RefCounted`, `src/overworld/follower_trail.gd`) implements the formula exactly: resamples each frame's `[p_prev, p_leader]` segment at `trail_sample_m` arc length (carrying leftover distance across frames so spacing never exceeds `trail_sample_m`), looks up each follower's position by walking backward from `p_leader` through the trail, and caps the buffer at `N_buf = ceil(n_f * follower_spacing_m / trail_sample_m - eps) + 2`.
- `OverworldMode` gained `_follower_trail: FollowerTrail` and a new public `step_followers(n_followers: int) -> void`, which is a **separate call from `_process()`**, not a step inside it. Deviation, flagged: story 005's `follower_no_collision_test.gd` fixes `_process()`'s behaviour as leader-movement only and is not in this story's Files list, so wiring the trail into `_process()` directly would have overwritten that test's `_follower_positions` fixture every frame (no roster exists yet to supply `n_followers` automatically -- that's story 008/010). `step_followers()` is the seam a future story's per-frame orchestration (or a roster-aware caller) drives; `test_process_alone_does_not_touch_follower_positions` in the new test file locks the non-regression in.
- `OverworldConfig` gained `follower_spacing_m` (default 0.9, range 0.7-1.1) and `trail_sample_m` (default 0.15, range 0.05-0.25), per GDD Tuning Knobs.
- `follower_trail_test.gd`: 9 tests -- the GDD's worked example (single frame appends 2 points 0.15 m apart; `N_buf` = 20 for defaults, re-run with a custom config), the main AC-4 polyline/spacing bound at `dt` = 1/60 s, `dt_max`, and a custom config (walks a real 90-degree-corner path, checks every follower against an independently-computed nearest-point-on-polyline arc length, gated on the buffer reaching steady-state `N_buf` rather than a raw distance threshold -- an earlier distance-based gate false-failed during bootstrap, before `N_buf` points of history existed), same-frame stop, and the `OverworldMode` integration plus its non-regression guard.

**Test Evidence Status**: `tests/unit/overworld/follower_trail_test.gd` exists and passes -- [x] Created and passing. Full suite: 675/675 (0 failures), run foreground via the standard harness.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/follower_trail_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (9 test cases; full suite 675/675)

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-005-followers-have-no-collision-or-triggers.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-007-followers-snap-on-entry-teleport-redirect-thaw.md`, `production/epics/overworld-exploration-encounters/story-008-solo-party-trail-and-mid-visit-recruit.md`, `production/epics/overworld-exploration-encounters/story-009-follower-facing-flip-hysteresis.md`
