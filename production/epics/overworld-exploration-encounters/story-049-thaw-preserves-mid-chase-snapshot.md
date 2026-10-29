# Story 049: Overworld → Battle → Overworld preserves a mid-chase snapshot except rule 7's changes

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (freeze by detach, `on_thawed`, exact snapshot restore); ADR-0012: Overworld Exploration & Encounters (the Overworld-side state this snapshot must cover)
**ADR Decision Summary**: Freezing the Overworld detaches it (never serializes it); thawing re-attaches the same instance, so every field not explicitly changed by rule 7 must come back exactly as it was.
**ADR Version**: ADR-0002 2026-10-21; ADR-0012 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Detach/re-attach preserving `Timer.time_left` and a node-bound `Tween`'s paused state was empirically probed on 4.7.2 headless (ADR-0002 Verification Required, items 1–2) — this story's snapshot assertions rely on that probed freeze behaviour actually holding for `OverworldMode`'s own timers.

**Control Manifest Rules (this layer)**:
- Required: Freeze by detach; two-step thaw with grace, Noticing/Chasing → Returning on every transition — ADR-0002, ADR-0012 §5
- Forbidden: Never serialize/restore the Overworld as a snapshot blob — the real mechanism is detach/re-attach (ADR-0002 Alternative 3, rejected)
- Guardrail: n/a

---

## Acceptance Criteria

- [ ] **AC-21 [I] (R7 × `game-state-scene-flow.md` AC-11)** GIVEN a mid-chase snapshot (symbol sub-states, timers, positions, trail, liberated sets), WHEN Overworld → Battle → Overworld runs with Fled, THEN every field equals the snapshot except those rule 7 changes (stun, push, grace, follower snap, and every Noticing or Chasing symbol switched to Returning when grace starts). The same holds for Victory, except for the resolved symbol, its payoff and its liberation.

---

## Implementation Notes

*Derived from ADR-0002's freeze-by-detach decision and ADR-0012 §5 (two-step thaw):*

This is the full round-trip integration test the preceding logic stories
(038–048) were each a slice of; it exercises the real `GameStateMachine`
transition sequence rather than calling `on_thawed` directly.

- Capture a full mid-chase snapshot: every symbol's sub-state and timers, the leader's and followers' positions, the trail buffer, and the liberated-marker sets per map.
- Run the real `OVERWORLD → BATTLE → OVERWORLD` transition sequence with a **Fled** result; assert every snapshot field is unchanged **except** the ones rule 7 names: the stunned/pushed symbol, grace having started, followers re-formed, and every symbol that was Noticing or Chasing at freeze time now in Returning.
- Repeat with a **Victory** result; assert the same invariance, except for the resolved symbol itself, its granted payoff, and its liberation state.
- This AC is explicitly cross-referenced against `game-state-scene-flow.md` AC-11 (the generic "freeze preserves an exact snapshot" guarantee) — this story is the Overworld-specific instance of that guarantee, scoped to the fields rule 7 actually touches.

---

## Out of Scope

- `story-043-victory-respawn-policy.md` through `story-048-timers-freeze-under-overlays.md`: the individual mechanisms this test exercises end-to-end.
- `story-014-overworld-snapshot-exact-restore.md` (game-state-scene-flow): the generic, Overworld-agnostic freeze/restore guarantee.

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/integration/overworld/thaw_preserves_snapshot_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/overworld/thaw_preserves_snapshot_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-047-encounter-grace-starts-on-reveal.md`, `story-048-timers-freeze-under-overlays.md`, `game-state-scene-flow/story-014-overworld-snapshot-exact-restore.md`
- Unlocks: None
