# Story 008: A solo party still records a trail, and a mid-visit recruit joins at the first slot

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: The `follower_trail` formula's `n_f` (number of followers) is calculated as `roster size − 1` and ranges 0–3; at `n_f = 0` the formula still runs (recording the trail), it simply has no follower positions to emit.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure arc-length bookkeeping; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: "Up to 3 followers are cosmetic `CharacterSprite`s, in Squad Roster order. Each replays the leader's recorded path at a fixed spacing" — source: GDD rule 2, ADR-0012 §2 positional ownership
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-5b [L] (R2)** GIVEN a party of one, THEN there are no followers but the trail is still recorded. A recruit added mid-visit appears at `s_1`.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and GDD rule 2:*

Edge Cases states this directly: "If the party has one member: there are no
followers. The trail is still recorded, so a recruit who joins mid-visit
appears correctly." The trail-recording step (append a point every
`trail_sample_m` of arc length) must never be gated on `n_f > 0` — it is the
follower-lookup step, not the recording step, that has nothing to read when
`n_f = 0`.

- With `n_f = 0`: confirm the trail buffer still grows every frame per the formula, and no follower sprite is instantiated or positioned (since Squad Roster order has only the leader).
- Scripted mid-visit recruit: once the roster grows to `n_f = 1`, the new follower must appear at `s_1 = 1 · follower_spacing_m` back along the trail that was already being recorded — not at the leader's current position, and not requiring the trail to be rebuilt from scratch.
- Squad Roster is a named dependency with no epic yet; this story treats the roster as the test harness's stub roster (per the AC preamble's test harness notes), not a system it implements.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: the steady-state trail/spacing formula for 1–3 followers.
- Story 007: trail reset on map entry/teleport/redirect/thaw.
- Squad Roster's own membership rules (named dependency, no epic yet).

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

**Status**: [x] Created and passing (2026-10-30, single-file run)

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-006-follower-trail-spacing-formula.md`; Squad Roster (named dependency, no epic yet)
- Unlocks: None

## Completion Notes (2026-10-30)

FollowerTrail.step() gains record_followers (buffer sized for max(n_followers, record_followers)); OverworldMode.step_followers() records for config.max_followers, so a party of one still records and a recruit appears at s_1 on the path already walked. Added get_trail_buffer_length(). Deviation: with n_f = 0 the buffer is N_buf(max_followers), not N_buf(0) = 2; the formula buffer of 2 points could not place a recruit at s_1, which the GDD Edge Case requires.

**Test Evidence**: tests/unit/overworld/follower_trail_test.gd (4 new tests, file 16/16 passing), default and non-default config.

**Files**: src/overworld/follower_trail.gd, src/overworld/overworld_mode.gd, tests/unit/overworld/follower_trail_test.gd
