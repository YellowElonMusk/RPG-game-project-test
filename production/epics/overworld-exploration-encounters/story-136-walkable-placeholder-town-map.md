# Story 136: A placeholder Paris Town map you can walk around in, with the leader sprite, followers and the follow camera

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-001`, `TR-overworld-002`, `TR-overworld-017`. There is no single TR for scene assembly: this story integrates the units the earlier stories built.

**ADR Governing Implementation**: ADR-0012 (the `OverworldMode` scene, `WalkGrid` baked from a `TileMapLayer`), ADR-0005 (the `DioramaStage` with one per 3D mode scene, `CharacterSprite`, `FollowCamera`, the `overworld` profile through `PresentationDirector`), and ADR-0002 (a mode scene that gets `setup()` through the loader's `pre_setup`).
**ADR Decision Summary**: one `DioramaStage` per 3D mode scene, and no second `Camera3D` or `WorldEnvironment`; movement is pure `GroundMover.step()` on a baked `WalkGrid`, with no physics nodes; sprites are `CharacterSprite`s on the actor layer.
**ADR Version**: ADR-0012 2026-10-23 · ADR-0005 2026-10-22 · ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0005)
**Engine Notes**: `TileMapLayer` is read once at load, as authoring data only. The actor shader needs the `[shader_globals]` declared in `project.godot`. `CharacterSprite` writes its uniforms only once it is in the tree.

**Why this story exists.** It was added 2026-10-29 by the main session. At `story_granularity: fine`, stories 001–135 each pin one rule, and the map-data stories (055, 073–080) assume a map already exists. Nothing assembled the first playable overworld scene. This is that vertical-slice step: it turns committed units into something a person can walk around in.

---

## Acceptance Criteria

- [ ] **AC-136** A windowed run reached by a debug launch (`res://src/overworld/overworld_demo.tscn`, or a `--debug-overworld` flag on `GameRoot`) shows:
  - a placeholder Paris Town diorama built as ONE `DioramaStage`, its walkable area authored as a `TileMapLayer` and baked into a `WalkGrid` at load;
  - the `overworld` lighting profile applied by `PresentationDirector` on entry;
  - the leader as a `CharacterSprite` with placeholder art, moved by the real `InputResolver` move vector through `GroundMover.step()`, stopping at walls and sliding along them;
  - up to three followers trailing on the follower trail, as `CharacterSprite`s;
  - the `FollowCamera` following the leader inside its dead zone and clamped to the map bounds.

  No physics nodes are used. The existing `ChapterMode` battle loop and `run/main_scene` stay unchanged. Evidence: a headless integration test of the assembly (bake, step, camera clamp), plus retained windowed screenshots of the leader at the map centre and against a wall.

---

## Implementation Notes

- **Scene.** `src/overworld/overworld_mode.tscn` holds the existing `OverworldMode` script, a `DioramaStage` child (its `profile_id` is `overworld`), the `FollowCamera` and the sprites. The map is a separate packed scene (`data/maps/paris_town_placeholder.tscn` or similar). Do not invent records beyond what the stage needs: `map_` records are story 055's.
- **Placeholder art.** Generated `ImageTexture`s are fine, or reuse the battle placeholders. Final art comes from `design/art/asset-list.md`.
- **Do not replace `ChapterMode`.** Battles still come from `ChapterMode` until visible symbols and contact exist (stories 020+, 038–039). The demo is a separate entry point.
- **Evidence.** Open every screenshot yourself before claiming what it shows (project memory: verify subagent visuals).

---

## Out of Scope

- Symbols, encounters, contact and battles (stories 020+, 038–049).
- Interactables and `probe()` (011–016).
- Occupation stages and clutter (053+).
- `map_` record validation (055, 073–080).
- Camp (088+).

---

## Files

- `src/overworld/overworld_mode.tscn`
- `src/overworld/overworld_mode.gd`
- `src/overworld/overworld_demo.tscn` (or a debug flag on `GameRoot`)
- `data/maps/` (the placeholder Town map scene)
- `tests/integration/overworld/overworld_walkable_map_test.gd`
- `production/qa/evidence/story-136-walkable-placeholder-town-map/`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/overworld/overworld_walkable_map_test.gd`, which must pass (BLOCKING).
- Retained windowed screenshots in `production/qa/evidence/story-136-walkable-placeholder-town-map/`.

**Status**: [x] `overworld_walkable_map_test.gd` 7/7 pass; full suite 682/682 (2026-10-29). The screenshots are retained in `production/qa/evidence/story-136-walkable-placeholder-town-map/`.

---

## Completion Notes

*Implemented 2026-10-29, awaiting /story-done.*

- **Launch:** `godot --path . res://src/overworld/overworld_demo.tscn` (or F6 in the editor). Debug builds only. It runs the real GameRoot chain: content boot, `InputResolver`, `ModeHostSceneLoader` with `pre_setup`, the machine and `PresentationDirector`. A copied `TransitionConfig` points OVERWORLD at `overworld_mode.tscn`, and the demo requests Title -> Overworld automatically. `run/main_scene` and `ChapterMode` are unchanged. Move with the arrow keys.
- **Screenshots (read back):**
  - `01`: tan floor, wall boxes and the back wall. All four actors stand on the spawn cell, so only the top one (orange) shows.
  - `02`: after real Right-key input, the red leader stands at the left face of a wall block (x = 15.7 = 16 - body_radius). Blue, green and orange trail to its left at even spacing, and the camera has panned right.
- **Engine finding / deviation:** with the `overworld` profile's `key_rotation_deg`, the key light points away from the camera, and the sprites rendered solid black. `KeyLight` now sits under a `KeyRig` pivot yawed 180°, and the sprites are lit. Escalate to `godot-shader-specialist` (ADR-0005): which way does the card normal and profile convention face?
- **Test note:** the headless viewport is 64x64, so the camera clamp is asserted through the formula and as a fixed point of `clamp_to_footprint`. It is not asserted as inside the map, because `clamp_or_centre` centres a footprint that is larger than the map.

- **Files.** New: `src/overworld/overworld_mode.tscn`, `overworld_map.gd` (`OverworldMap`: bakes the walk layer, builds the set boxes from the grid), `overworld_view.gd` (`OverworldView`: follower trail, `FollowCamera`, sprite placement), `placeholder_actor_frames.gd`, `overworld_demo.gd` and `.tscn`, `data/maps/paris_town_placeholder.tscn` (a 24x16 `TileMapLayer` with a `walk` custom data layer), and `tests/integration/overworld/overworld_walkable_map_test.gd`. Changed: `overworld_mode.gd` gains `map_scene`, `map_parent`, `load_map()`, `get_walk_grid()` and `get_map()`, and `_process()` now passes the baked grid in place of `null`.
- **Deviation.** Followers and the camera live in `OverworldView`, not in `OverworldMode._process()`. Stories 005 and 006 lock `_process()` to leader-only movement.
- Status synced 2026-10-30 from commit 54b0ef7.

## Dependencies

- Depends on:
  - `production/epics/overworld-exploration-encounters/story-001-leader-speed-from-move-input.md`
  - `production/epics/overworld-exploration-encounters/story-004-wall-slide-and-corner-assist.md`
  - `production/epics/overworld-exploration-encounters/story-005-followers-have-no-collision-or-triggers.md`
  - `production/epics/overworld-exploration-encounters/story-006-*` (follower trail)
  - `production/epics/sprite-camera-presentation/story-005-no-mirror-animations-use-authored-art.md` (actor shader)
  - `production/epics/sprite-camera-presentation/story-008-mode-entry-applies-lighting-before-reveal.md`
  - `production/epics/sprite-camera-presentation/story-023-follow-camera-matches-the-formula.md`
- Unlocks: walking playtests; symbol and encounter stories now have a scene to live in.
