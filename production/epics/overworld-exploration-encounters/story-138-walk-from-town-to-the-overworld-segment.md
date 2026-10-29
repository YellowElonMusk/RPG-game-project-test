# Story 138: The party walks out of Town through a MapExit into the overworld segment, where the Clerks patrol

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md` (MapExit / EntryPoint rules, rule 13 Town has no symbols, follower snap on entry)
**ADR Governing Implementation**: ADR-0012 (map change as a fresh-instance transition through ADR-0002; MapExit, EntryPoint and `map_` records); ADR-0002 (Overworld → Overworld map change row).

Story 137 made the game boot into one placeholder Town map, with the two Clerk symbols placed in Town and `map_exit_requested` left as a stub. The GDD puts no symbols in Town (AC-30b): street fights live on the overworld segment. This story adds that second map and the walk between them, so the player-visible loop is Town → segment → fight → back to Town.

## Acceptance Criteria

- [x] **AC-138a [I] (map change)** GIVEN the leader enters a MapExit rectangle in Town, THEN Game State runs the map-change transition to a fresh instance of the target map, and the party appears at the exit's target EntryPoint facing into the map, with followers snapped into formation (story 007's rule). The reverse exit returns to Town at its own EntryPoint.
- [x] **AC-138b [I] (re-fire)** A MapExit fires once per entry: standing in the rectangle after arrival does not re-fire; the leader must leave and re-enter it (story 081's rule).
- [x] **AC-138c [D] (records)** Town and the segment each have a `map_` record (fields per Content Data rule 1; `base_stage` per story 055 where it applies); every MapExit names an existing map and EntryPoint, and every EntryPoint sits clear of every MapExit rectangle (story 080's rule), checked by a load-time validator.
- [x] **AC-138d [I] (symbols moved)** Town holds 0 symbols. The segment holds the two Clerk symbols (`enc_paris_clerks_west`, `enc_paris_clerks_east`); a Victory there and a walk to Town and back respawns them per their respawn policy (re-entering the map).
- [x] **AC-138e [UI evidence]** Retained windowed screenshots in `production/qa/evidence/story-138-town-to-segment/`: Town at the exit, the segment just after arrival with a Clerk in view, and Town again after walking back. The main session opens each one before closing the story.

## Implementation Notes

- A placeholder segment map (`data/maps/paris_segment_placeholder.tscn` or similar) built like story 136's Town: one `DioramaStage`, walkable area as a `TileMapLayer` baked into a `WalkGrid`, no physics nodes.
- If this closes stories 007, 080 or 081 outright, update those story files too and say so in the report; otherwise leave them Ready and name what remains.
- Run-and-observe is required (`.claude/docs/run-and-observe.md`).

## Out of Scope

- Stages, decree gags and permits timing (053–057); checkpoints (070–073); the dungeon, story encounter and boss (075); payoffs (050–052); camps.

## Files

- `src/overworld/` (OverworldMode exit handling, a MapExit/EntryPoint marker script if needed), `src/game_state/` map-change wiring if missing
- `data/maps/*.tscn`, `data/maps/map_*.tres`
- `tests/integration/overworld/town_to_segment_map_change_test.gd`

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/overworld/town_to_segment_map_change_test.gd` passes; screenshots per AC-138e.
**Status**: [x] `town_to_segment_map_change_test.gd` 6/6 and `tests/unit/overworld/map_validator_test.gd` 5/5 pass; full suite 824/824 (2026-10-29). Screenshots in `production/qa/evidence/story-138-town-to-segment/`.

## Dependencies

- Depends on: story 137 (3947071)
- Unlocks: story 075 (dungeon story encounter and boss placement), story 055

## Completion Notes

- **Map change:** `MapExit` / `EntryPoint` markers (`src/overworld/map_exit.gd`, `entry_point.gd`), `MapEntryPayload` (`src/game_state/map_entry_payload.gd`). `OverworldMode` requests the existing `OVERWORLD -> OVERWORLD` fade row on an exit's enter edge; the fresh instance loads the target scene by convention and places the party at the EntryPoint, followers snapped behind (`FollowerTrail.snap`). `GameRoot` keeps `WorldState` and the squad across a `MapEntryPayload`.
- **Records/validator:** `data/maps/map_paris_{town,segment}_placeholder.tres`; `MapValidator` runs in `GameRoot._ready()` (push_error per problem).
- **Deviations (flagged):** map scenes live at `data/maps/<name>.tscn` (`OverworldConfig.map_scene_dir`), not ADR-0012's `scenes/maps/<id>/<id>.tscn`; MapExit rect authored in ground metres, not from the transform; the swap uses the loader's generic free-then-add (no detach/rollback); `WorldState.on_map_entered` still runs in `load_map()`, not on `mode_entered`; both Clerk records now `respawn = true` (were `false`) so AC-138d's respawn is observable.
- **Screenshots (read back):** `01`: Town, an orange-tinted party sprite next to the blue exit patch at the right edge; the red leader is not separately distinguishable. `02`: the grey segment just after arrival, a dark Clerk sprite mid-frame, red leader and a blue follower at the left edge (camera still settling). `03`: Town after walking back, red leader at the from_segment entry with blue, green and orange followers in a line behind it toward the blue exit patch.
