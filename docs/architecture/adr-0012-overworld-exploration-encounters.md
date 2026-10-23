# ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine

## Status
Accepted 2026-10-23 (user confirmed; revision 3, synced to GDD rev 4). Its amendments to ADR-0001 (record types `map`, `encounter`, `occupation_stage`; `faction.patrol_archetype_id`), ADR-0002 (§4 annotations and the §11 revision) and ADR-0005 (§4 skip scope, profile resolution) are now in effect. The Overworld GDD now exists (`design/gdd/overworld-exploration-encounters.md`, rev 4, **Approved** 2026-10-23), and this revision folds in its OQ-3 amendment list (items 0–25), then the TD-ADR and godot-specialist conditions of the 2026-10-23 architecture review. **It can be Accepted once `/architecture-review` assigns the GDD's TR IDs** and the GDD's re-review does not change the contracts below. architecture.md Required ADRs, item 6, tracks it.

## Date
2026-10-22 (rev 1–2); 2026-10-23 (rev 3)

## Last Verified
2026-10-23

## Decision Makers
- **User:** autonomous mode. Decisions are logged in `production/session-logs/decision-log.md`.
- **Claude:** orchestrating session.
- **Reviewers:** godot-specialist (engine validation, probed on 4.7.2) and technical-director (TD-ADR).

Revision 2 folded in both rev-1 reviews. Revision 3 adopts the Overworld GDD's design: its invariants, the symbol AI contract, the occupation-stage data and the Game State amendments it needs.

## Summary
Overworld Exploration & Encounters is the MVP system the user asked for after Content Data. Three Accepted ADRs already constrain it:
- **ADR-0002** fixes its mode contract: freeze by detach, `on_thawed`, the Encounter descriptor and the transitions.
- **ADR-0003** fixes its input: `get_move_vector()`, and no pointer in the overworld.
- **ADR-0005** fixes its camera (the ground-plane `follow_camera` formula) and its sprites (upright cards at the feet).

Decided, as architectural invariants:
- The party moves continuously on a logical 2D ground plane. A pure `GroundMover` resolves collision against a `WalkGrid` baked from an editor-authored `TileMapLayer`, with a runtime blocker overlay. **No physics engine is used for any overworld movement or trigger.**
- Maps, encounters and occupation stages are data. `map`, `encounter` and `occupation_stage` are new record types, and a map's scene path is derived from its ID, never stored.
- Encounters start only from visible symbols in MVP (zones stay supported in code and data, at rate 0). A pure `SymbolBrain` runs each symbol's sub-state machine.
- Persistent world state lives in an injected `WorldState`, the single owner of the party's map and position. It survives map changes, battles and saves.

Feel values are set by the GDD's Tuning Knobs and live in `OverworldConfig` or records.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scripting) + Navigation (grid pathing). **No Physics** |
| **Layer** | Feature |
| **Knowledge Risk** | LOW–MEDIUM. Movement, triggers and symbol AI are pure GDScript. `TileMapLayer` is used only as an authoring and data source, read at load. `AStarGrid2D` predates the cutoff. Jolt is never touched |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `modules/physics.md` (Jolt is the 3D default since 4.6; 2D is unchanged); `modules/navigation.md`; `breaking-changes.md` (TileMapLayer rows); `deprecated-apis.md` (`TileMap` → `TileMapLayer`); `current-best-practices.md` |
| **Post-Cutoff APIs Used** | None at runtime. At load, for the bake only: `TileMapLayer.get_used_cells()`, `get_cell_tile_data()` and `TileData.get_custom_data()` |
| **Verification Required** | **Probed on 4.7.2 (godot-specialist, 2026-10-22, rev 1):**<br>(1) A `TileMapLayer` under a `Node3D`, with `visible = false` and `collision_enabled = false`, creates **0** 2D physics objects, raises no warnings and frees cleanly. **PROBED.**<br>(2) `get_cell_tile_data(c).get_custom_data(&"walk")` and `get_used_cells()` work. **PROBED.** Gotcha: add the source to the `TileSet` before `TileData.set_custom_data()`.<br>(3) `AStarGrid2D` (`region`, `cell_size`, `diagonal_mode`, `set_point_solid`, `update`, `get_id_path`) has no renames and routes correctly. **PROBED.**<br>(4) `collision_enabled` and `navigation_enabled` are unchanged on 4.7.2. **PROBED.**<br>**Probed on 4.7.2 (godot-specialist, 2026-10-23, GDD review 2):**<br>(5) `AStarGrid2D.update()` after a `region` change clears **every** solid flag and weight; a solid start or target returns an empty path; `allow_partial_path = true` works. **PROBED** → §2 bake order.<br>(6) After a 600 ms stall, `_process` `delta` was 0.1333 (`max_physics_steps_per_frame` 8 / 60 ticks). `dt_max` ≤ 0.10 still binds. **PROBED.**<br>(7) An unreachable `get_id_path` query floods the component: ~0.1 ms on 40×30 and 25×50 grids, 0.39 ms on 60×60 (desktop; expect ~3× on the Deck). **PROBED** → §5 component labels.<br>(8) `GridMap.collision_layer` defaults to 1; `CSGShape3D.use_collision` defaults to false; `SoftBody3D`, `RayCast3D` and `ShapeCast3D` are not `CollisionObject3D`s. **PROBED** → §3 `validate_maps` class list.<br>(9) First `OmniLight3D` in a scene: +1 surface pipeline; enabling its shadow: +1 specialization pipeline; moving it: 0. **PROBED** → ADR-0005 amendment (§7).<br>**Probed on 4.7.2 (godot-specialist, 2026-10-23, GDD review 3):**<br>(10) `update()` does nothing unless `is_dirty()`; only `region`, `cell_size` or `offset` make the grid dirty; a dirty query logs "Grid is not initialized" and returns `[]`; a solid origin returns `[]` even with `allow_partial_path` (a call argument, not a property). **PROBED**.<br>(11) `process_priority` sorts all nodes globally, ignoring parent/child order; `_physics_process` uses `process_physics_priority`. **PROBED**.<br>(12) 4-connected component relabel on 60×60 with 25% walls: 0.83 ms per full pass; A* to an unreachable target 0.20 ms. **PROBED**.<br>(13) `CSGShape3D.bake_static_mesh()` returns null before tree entry and on the same frame, a valid mesh one frame later; `AnimationMixer` manual callback mode plus `advance()` exist. **PROBED**.<br>Detaching a physics-free subtree, and per-visit RNG seeding, need nothing special. **REASONED** |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001** (Content Data, **Accepted**): record types, IDs, the generic reference pass. Extended additively by `map`, `encounter` and `occupation_stage`, and by one `faction` field.<br>**ADR-0002** (Game State, **Accepted**): `GameMode`, freeze/thaw, `on_thawed`, `EncounterDescriptor`, `BattleEntryPayload`, the transitions, `get_move_vector(self)`, `last_camp_id`, ChapterMode's interim role (§8). Amended additively.<br>**ADR-0003** (Input, **Accepted**).<br>**ADR-0004** (Boot ordering, **Accepted**).<br>**ADR-0005** (Sprite & Camera, **Accepted**): `DioramaStage` and its `profile_id`, `FollowCamera` and `follow_camera`, `CharacterSprite`. Amended additively.<br>**ADR-0013** (Localization, **Accepted**): `LocText` for poster, decree and card text |
| **Enables** | The Overworld epic; deleting ADR-0002 §8's interim `ChapterMode`/`ChapterFlow` encounter sequencing; Camp & Party Management's entry and exit; the NPC hook of Dialogue, Banter & Quests; the Overworld save participant (ADR-0009) |
| **Blocks** | The Overworld Exploration & Encounters epic and every overworld story |
| **Ordering Note** | **Additive amendments, annotation only, effective on acceptance:**<br>- **ADR-0001:** three record types, `map` (prefix `map_`), `encounter` (prefix `enc_`) and `occupation_stage` (prefix `ostage_`), plus `faction.patrol_archetype_id`. The Content Data GDD's Rule 1 table needs the same addition (Overworld GDD OQ-4).<br>- **ADR-0002:**<br>&nbsp;&nbsp;(a) `OVERWORLD → OVERWORLD` swaps to a **fresh instance**, specified in §4;<br>&nbsp;&nbsp;(b) `Overworld → Camp` carries a `CampEntryPayload`, and the machine records `last_camp_id` from it during SWAP;<br>&nbsp;&nbsp;(c) the composition root's `pre_setup` hook (introduced by ADR-0008 and ADR-0009) is a composite injector that also assigns `world_state`;<br>&nbsp;&nbsp;(d) **not an annotation — an ADR-0002 revision** (§11, written 2026-10-23 at TD-ADR's request, effective with this ADR's acceptance): `request_in_mode_fade(callback)`, the same-instance fade used by the checkpoint redirect (zero-length SWAP, only `transition_started`/`transition_finished`, `is_in_mode_fade()`), and `register_camp(camp_id)`, the second input to `last_camp_id`. The §8 note keeps the chapter step list as interim data.<br>- **ADR-0005 §4:** the same-mode skip of the entry-profile apply applies only to the **same-instance** `BATTLE → BATTLE` row.<br>- **ADR-0005 (§7 below):** an in-mode fade (`from == to`, no `mode_entered`) triggers no rebind and no profile apply; lighting profiles keyed by map × faction × stage plus a liberated profile; `sky_card`; the interior travelling light's constraints; tilt-shift blur bounds per the GDD's `chase_visibility`, with DOF depth semantics confirmed in its Step 1; per-cue capture-ID tags in the §13 capture tool.<br>- **Control manifest:** no `Engine.time_scale` anywhere (next to the `SceneTree.paused` ban).<br>**Not a dependency:** ADR-0009. The overworld save participant registers when ADR-0009 is implemented, and this ADR fixes the single owner of map and position. ADR-0009 §3 is revised to match |

## Context

### Problem Statement
ADR-0002 §8 put a placeholder `ChapterMode` in the Overworld slot. It is a fixed sequence of fights with no map, and it keeps the MVP's loop playable. The game concept's loop is "Overworld travel → battle → combo → Codex", in the Dragon Quest lineage. The Vertical Slice is one region: occupied Paris, with a town, an overworld segment, a dungeon and a boss chamber.

What is already fixed around the Overworld:
- **Its camera.** Perspective, at a fixed yaw and pitch, following the party on a **ground plane** in metres and clamped to the map (ADR-0005, GDD `follow_camera`).
- **Its sprites.** Upright cards, with pixel-snapped feet.
- **Its lifecycle.** It is detached during battles and restored exactly (ADR-0002 §4), then receives `on_thawed`.
- **Its encounter payload.** `EncounterDescriptor`.

The Overworld GDD (rev 4, Approved) now fixes the design: visible symbols only, a symbol sub-state machine with path-distance give-up, occupation stages raised on the faction's schedule, local and region liberation, checkpoints with fight-free requirement sources, one confirm-started story encounter per region, and a guaranteed walk home after the boss.

### Constraints
- **ADR-0005's camera works in continuous ground-plane metres.**
- **ADR-0002:**
  - detach and restore are exact;
  - the Menu stops mode time;
  - only Game State switches modes;
  - movement is polled through `machine.get_move_vector(self)`;
  - `last_camp_id` is read-only to everyone but the machine.
- **Content Data Rule 3:** the catalog never names a file path. Art is referenced by asset ID.
- **Steam Deck:** an analog stick is a primary input; the CPU is roughly a third of the desktop reference.
- **Testability:** every acceptance criterion should run headlessly, deterministically.

### Requirements
- Continuous party movement with wall sliding, deterministic and independent of frame rate.
- Maps authored in the editor: the 3D set, walkability, entries, exits, camp spots, NPCs, symbols, checkpoints, gags and stage-gated clutter.
- Encounters as data whose fields are exactly the Encounter descriptor's, plus a victory payoff.
- One encounter pipeline. Victory and Fled are resolved per ADR-0002 and the GDD's two-step thaw.
- World state survives battles, map changes and saves, with one owner for the party's map and position.
- No physics bodies, 2D or 3D, in the Overworld.

## Decision

### Architectural invariants

**1. Coordinates: a 2D ground plane in metres.**
- Overworld logic works in `Vector2` ground coordinates: `x` is east, `y` is south. ADR-0005's `follow_camera` uses the same plane.
- One walk cell is `cell_m` metres (1.0 in MVP, from `OverworldConfig`).
- A ground point `p` renders at `Vector3(p.x, 0, p.y)`. MVP maps are flat; multi-level maps get a later ADR.
- Logic never reads a 3D transform back.

**2. Movement and the walk grid.**
- **One clock.** All overworld logic steps on `ow_dt = min(delta, dt_max)`, accumulated only while the mode is in Exploring. `dt_max` is **Presentation's** knob (`sprite-camera-presentation.md`); the Overworld reads it and does not duplicate it. Overworld sprite animation is driven from `ow_dt` too (frame and progress set by the mode, or an animation player in manual mode with `advance(ow_dt)`), so animation never drifts from logic.
- **Process order.** Everything runs in `_process`; nothing overworld runs in `_physics_process`. `process_priority` sorts nodes globally regardless of tree order (probed), so the values are pinned: `GameRoot` (which calls `machine.tick`) −20, `OverworldMode` −10, `FollowCamera` 0, `CharacterSprite`s +10. The machine ticks first, so a fade callback runs before the mode's step and must write `WorldState` itself; the camera never lags a frame.
- **`WalkGrid`** (`RefCounted`) has `size`, `cell_m`, and `cells: PackedByteArray`. Bits: 0 = walkable (baked), 1 = `SAFE`, 2 = runtime-blocked, others = terrain tags (zone).
  - It is baked **once at map load** from the map scene's `WalkLayer`, a `TileMapLayer` with a custom data layer `walk: bool` (and `zone: int`), set `visible = false` and `collision_enabled = false`. The layer is freed after baking.
  - `SAFE` is baked conservatively from every EntryPoint, MapExit rectangle, CampSpot and checkpoint return marker within `safe_radius_m` (GDD rule 0).
  - Cells outside the grid are blocked. The grid's extent × `cell_m` **is the map's bounds** for ADR-0005's `follow_camera`.
  - **Runtime blocker overlay.** `set_blocked(cells, on)` (batched) is the single path that changes blocked cells (closed checkpoints, queues, tape, stage-activated blockers, the last-leg exit disable). It updates the leader's grid and the symbols' `AStarGrid2D` together, invalidates stored symbol paths and notice caches, bumps a grid revision counter, and marks the **4-connected** symbol-legal component labels for one relabel per frame (a full relabel costs ~0.83 ms on 60×60, probed).
  - **Bake order (probed, items 5 and 10).** `AStarGrid2D.update()` rebuilds only when `region`, `cell_size` or `offset` changed (dirty), and that rebuild clears every solid and weight; a query on a dirty grid returns `[]` silently. So `update()` is called **once**, at bake; those three properties are frozen afterwards; walls, `SAFE` cells and initially active blockers are applied after it with `set_point_solid`; later changes go only through `set_blocked()`; debug builds assert `not is_dirty()` before every query. `AStarGrid2D` is pinned for determinism: `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`, jumping off, a fixed heuristic (octile), `cell_size` = `cell_m`; `get_id_path` is always called with `allow_partial_path = false`, from an origin snapped to the nearest symbol-legal cell (a solid origin returns `[]`, probed).
- **`GroundMover.step(pos, input_vec, dt, grid, cfg, speed, blocked_mask) -> MoveResult`** is a static, pure function, used by the leader and by symbols:
  1. **Velocity.** `velocity = input_vec.limit_length(1) × speed` (the leader passes `walk_speed`; symbols pass `v_patrol` or `v_chase`).
  2. **Axis-separated collision.** Resolve x, then y, against cells in `blocked_mask` (the leader: baked walls + runtime-blocked; symbols: those plus `SAFE`), using `cfg.body_radius`. Walls slide.
  3. **Corner assist (leader only).** If `cfg.corner_assist_m > 0` and the blocked axis's overlap with a cell corner is ≤ `corner_assist_m`, nudge along the free axis by at most that overlap, toward the open side.

  `MoveResult` carries `position`, `blocked_x`, `blocked_y` and `distance_moved`. A symbol following a path treats a waypoint as reached within `cfg.waypoint_tol_m`.
- **Facing** is stored as a `Vector2`: the last non-zero `input_vec`, normalized. `CharacterSprite` maps it to the sprite set's facings. A symbol's **logical** facing is snapped to its displayed facing (GDD rule 5).
- **Driving.** `OverworldMode._process(delta)` reads `machine.get_move_vector(self)` (zero while locked) and steps with `ow_dt`. Nothing moves while the Menu is open. **No `Engine.time_scale`** (control manifest).
- **No physics.** The Overworld uses no `CharacterBody`, `Area`, `RigidBody`, `SoftBody3D`, ray/shape cast or collision shape, in 2D or 3D. Diorama props are visual only.

**3. Maps, encounters and stages are data.** *Additive amendment to ADR-0001.*

**`MapData`** (record type `map`, prefix `map_`, file `data/maps/map_<name>.tres`):

| Field | Notes |
|---|---|
| `display_name` | `LocText` |
| `faction_id` | The occupying faction, for stage records and lighting; empty for unoccupied maps |
| `base_stage`, `stage_table` | Stage 1–3 and `{flag → stage}`; absent for maps with no stage (camp interiors, the boss chamber) |
| `critical_path` | Legs `{id, from: EntryPoint, to: MapExit \| symbol_id \| CampSpot}` |
| `region_liberation_flag` | The region's boss flag |
| `liberated_profile_id`, `liberated_kit_id` | Required for maps reachable after region liberation |
| `encounter_zone_ids: PackedStringArray`, `zone_rate` | Zone mechanism kept; `zone_rate = 0` on every MVP map (CI) |
| `new_game_entry` | Optional: the marker used when New Game starts on this map |

There is **no file path**: the map scene is `res://scenes/maps/<map_id>/<map_id>.tscn` by convention (Content Data Rule 3).

**`EncounterData`** (record type `encounter`, prefix `enc_`): exactly the descriptor's fields (`enemy_ids`, `battle_stage_id`, `faction_id`, `is_boss`, `can_flee`, `retreat_allowed`), plus `respawn` (`never` / `on_map_reenter` / `on_rest`) and `victory_payoff` (`clue` with a facet ID, `open` with a checkpoint marker ID, `item` with an item ID, or empty).

**`OccupationStageData`** (record type `occupation_stage`, prefix `ostage_`), keyed by faction × stage: caps per clutter kind (non-decreasing in stage, invariant I13), civilian density and pool, lighting profile ID, `sky_card`, set kit ID, ambience bed ID, ambient particle density, name-card subtitle (`LocText`), `liberation_grumble_min`, and `decree_gag_by_flag` (the decree-gag marker kind each raising flag shows; the markers themselves are placed in the map).

**`FactionData`** gains `patrol_archetype_id` (the faction's symbol look and behaviour preset).

**The map scene** contains one `DioramaStage` (ADR-0005), one `WalkLayer`, and marker nodes (`src/overworld/markers/`, plain `Node3D`s), each with a `marker_id` unique within the map. A marker's **ground position** is the `x`/`z` of its transform **relative to the map root**, composed from the local `transform`s of its ancestors up to the root. `global_*` is never read: markers are read before the map enters the tree, where `global_position` returns the origin on 4.7.2 (probed, GDD review / architecture review G1). Every marker may carry `min_stage` and `recruit_remark`.

| Marker | Fields |
|---|---|
| `EntryPoint` | facing |
| `MapExit` | target `map_` ID, target entry `marker_id`, trigger rectangle |
| `CampSpot` | `camp_id`, its return `EntryPoint`, `is_region_default` |
| `NpcSpawn` | `npc_id`, an opaque dialogue reference, optional `bark` (`LocText`) and tags (`faction_clue`, `optional_teach`) |
| `EncounterSymbol` | `enc_` ID, `symbol_id`, patrol path (polyline + `loop` / `pingpong`), or **Static** with `start_on` (`contact_or_confirm` / `confirm`) and a return marker |
| `Interactable` | `interact_id`, `kind`: `gag` (response `line` / `change` / `clue`, text `LocText`, tags), `checkpoint` (requirement, `obtained_at`, failure outcome `redirect` / `queue` / `encounter`, return marker, linked `enc_`), `pickup` (item or flag), `decree_gag` (raising flag or first-sight trigger, text `LocText`) |
| `Clutter` | kind (poster, queue, tape…), `blocks_route`, optional `symbol_id`, `liberation_flag`, payoff-tell role |

**`tools/ci/validate_maps.gd`** runs in CI after `validate-content.gd`. It runs `ContentBootstrap.run()` first (ADR-0004), loads every map scene headlessly, bakes it, and asserts every [D] criterion of the Overworld GDD, including:
- exactly one `DioramaStage`; a `WalkLayer` with a `walk` custom data layer;
- **no physics nodes**, by class: `CollisionObject2D/3D`, `SoftBody3D`, `RayCast2D/3D`, `ShapeCast2D/3D`, `SpringArm3D`, `Joint2D/3D`, `PhysicalBoneSimulator3D`, and the deprecated `TileMap` (it still builds collision); no `CSGShape3D` at all in shipped maps (baked to `MeshInstance3D`); every `GridMap` with `collision_layer = collision_mask = 0` and no item shapes; every `TileMapLayer` with `collision_enabled` off (both default to on);
- story encounter and boss placement (the `confirm`-started Static exemption, return-marker distance, telegraph from the camp's safe-zone edge); `return_safe_radius_m` discs clear of patrols; no route round the story encounter with every optional checkpoint open; junction coverage of each leg's beacon chain and I18; reachable stages derived from the ChapterFlow step list;
- unique marker IDs; every reference resolves (`enc_`, `map_`, `symbol_id`, flags against the interim flag registry, payoffs, items, `obtained_at`, `recruit_remark`, decree gags);
- placement: EntryPoints clear of MapExit rectangles; patrol segments clear of safe zones and symbol-legal at every reachable stage; story encounter and boss placement; payoff tells within `R_vis`; clue and teaching-beat ordering;
- per leg and stage: the ordered bypass search, the pressure floor, the first-patrol ratio, density bands, the walk budget (with `passes` counted from the ChapterFlow step list);
- stage raises: never triggered by a Victory or map entry; only on maps reached after the step; a decree gag at every usable EntryPoint;
- every `MapData` has a scene at its conventional path; every `battle_stage_id` has a scene at its conventional path.

**4. `OverworldMode`, `WorldState`, entry paths and map change.**

**`WorldState`** (`RefCounted`, `src/overworld/world_state.gd`) is the **single owner** of everything that must outlive a map visit:
- `map_id`, `party_pos`, `party_facing`;
- `camp_returns: {camp_id → {map_id, marker_id}}`, filled when a camp is registered or entered. The camp's **return point is derived**, never stored twice: `camp_returns[machine.last_camp_id]`, falling back to the region default camp's return. `last_camp_id` itself lives only in the machine (ADR-0002 §11);
- `chapter_step`: the index of the current ChapterFlow step (interim; see §8). Its only writer is `OverworldMode`;
- per map: resolved symbols, opened interactables, liberated markers, `stage_stored`;
- granted payoffs;
- `rest_counter`;
- `story_flags`, which are **interim** (see below).

`OverworldMode` writes `party_pos` and `party_facing` every frame; every other field is written only when its event happens, and nothing per-frame emits a change signal or reaches the save path. This bumps the `overworld` save section's schema version.

How it is created and injected: `GameRoot` creates it; the composite `pre_setup` injector assigns `ui` (ADR-0008), `presentation_settings` (ADR-0009) and `world_state`; `OverworldMode._ready()` asserts it is non-null. It is never an autoload. ADR-0009's **`overworld`** save participant captures it; Game State's section keeps only `last_camp_id`.

**Interim `story_flags`.** They are deleted from `WorldState` when the Dialogue, Banter & Quests ADR claims global flags; the section's schema version is then bumped and a `migrate()` step moves them.

**`OverworldMode extends GameMode`** holds only per-visit state: actor positions, symbol brains, the trail, timers. Entry paths:

| Payload | Where the party is placed | Respawn |
|---|---|---|
| `MapEntryPayload { map_id, entry_marker_id }` | At that marker. Used for a map change, leaving camp and the walk home | `on_map_reenter` applied |
| `LoadedSave` (Continue) | At `world_state.map_id` / `party_pos` / `party_facing`, committed by ADR-0009 during SWAP. A position now in a blocked cell moves to the nearest walkable cell by BFS (≤ 5 m), else to the first EntryPoint | **not** applied |
| `null` (New Game) | `reset_to_new_game()` set `OverworldConfig.new_game_map_id` and its `new_game_entry` | — |

`WorldState.on_map_entered(map_id, entry_kind, catalog)` takes the entry kind so Continue skips respawn.

In `_ready()`, `OverworldMode`:
1. looks up `MapData` and computes the stage (`occupation_stage` formula) and region liberation;
2. instantiates the map scene from its conventional path;
3. bakes the `WalkGrid` (then the pathing setup of §2);
4. activates markers (`marker_activation`, sorted by `min_stage` then marker order) and applies active blockers;
5. builds actors as `CharacterSprite`s;
6. places the party;
7. sets `stage.profile_id` to the resolved profile (§7) **before the stage enters the tree**.

`_ready()` builds only per-visit state. It **writes nothing to `WorldState`**: the map, position, facing, respawn (`on_map_entered`) and `stage_stored` updates are committed on `mode_entered(OVERWORLD)`, after the swap has succeeded, so a map change that rolls back leaves `WorldState` describing the old map (architecture review G2).

**`OVERWORLD → OVERWORLD`** (map change, fade). *Annotation on ADR-0002.* The `SceneLoader` **detaches** the old `OverworldMode` (the freeze path, which §4 already makes `_exit_tree`-tolerant), instantiates and adds the new one with its `MapEntryPayload`, and frees the old one only when the new one succeeds; on failure it frees the new one and re-adds the old one (`rollback_swap()`). `ModeHost` therefore never holds two live modes (ADR-0002 §2). All four transition signals fire with `from == to == OVERWORLD`, and the `PresentationDirector` applies the new map's entry profile.

**Camp.** *Annotation on ADR-0002.*
- **Registering.** When the leader enters a CampSpot's safe zone, `OverworldMode` checks the `camp_id` against the current map's CampSpots (an unknown ID is logged as an error), calls `machine.register_camp(camp_id)` (ADR-0002 §11) and fills `world_state.camp_returns[camp_id]`. No rest is needed.
- **Entering.** `confirm` → CampPrompt → Yes requests `CAMP` with `CampEntryPayload { camp_id }`; the machine records `last_camp_id` during SWAP, and `camp_returns[camp_id]` is filled the same way.
- **Retreat** is Game State's: `choose_retreat()` → `CAMP` (ADR-0002 §4).
- **Leaving camp** (after a rest or a Retreat) requests `OVERWORLD` with a `MapEntryPayload` to the **derived** return point, `camp_returns[machine.last_camp_id]` (or the region default camp's return).

**Region end (the walk home).** After the boss's post-battle Dialogue, `OverworldMode` advances `world_state.chapter_step` to the last act's first step (A) and requests `OVERWORLD` with a `MapEntryPayload` to the overworld segment's dungeon-side EntryPoint. Entering Town advances it to step B. That map loads liberated, and during the last act its exit to the dungeon is disabled through `set_blocked` with an in-world tape blocker, so the dungeon and boss chamber cannot be re-entered. The squad walks to the region default camp; `confirm` there opens a P15 "End the chapter here?" prompt (No focused), and Yes ends the chapter.

**5. Encounters and the symbol brain.**
- **`start_encounter(enc_id, source)`**: build an `EncounterDescriptor` from the record; build `BattleEntryPayload { descriptor, party }` (party from the Squad Roster; until its ADR, from ChapterFlow's interim party source); remember `pending_source`; call `machine.request_transition(Mode.BATTLE, payload)`. A rejected request leaves the touched symbol in **contact pending** (it holds still) and retries next frame.
- **`SymbolBrain`** (`RefCounted`, pure, one per symbol) owns the GDD rule 5 contract: sub-states Patrol / Noticing / Chasing / Returning / Stunned / Static; the turn pause (old facing until the flip); facing snapped to the displayed facing with 45°+5° hysteresis and held while stopped; the notice test (cheap checks first: radius by half-plane, not `SAFE`, same component; then a **bounded** uniform-cost (Dijkstra-style, √2 diagonals) search capped at `notice_path_cap_m`, its waypoints cached per symbol and cleared by `set_blocked`); chase target with per-symbol sideways offset; the final approach only when the leader's cell is the path target, the leader is not `SAFE` and every crossed cell is legal, stepped by `GroundMover` with the symbol mask; `path_dist = arc(c_S → w_last) + |w_last − c_L(t₀)| + d_L(t₀ → t)` (a real route length, hence an upper bound; the gap counts as +∞ when the leader stood in a `SAFE` cell at t₀ or the gap crosses a non-walkable cell); pending paths; the give-up test; the resume point (including contact during Patrol); the re-notice cooldown; Static `start_on`.
- **Query budget.** Notice searches, chase repaths and Returning paths share `repath_per_frame_max` per frame through a **round-robin** cursor (oldest deferred first), so every request is served within `⌈N_req / budget⌉` frames.
- **Per-frame order** (Exploring): move the leader → check map exits (enter-edge only) → step symbols in marker order → swept contact (eligibility read after the steps) → interaction requests.
- **Contact** is a swept circle test (GDD `frame_step_safety`), never a physics query.
- **Resolution, two steps** (ADR-0002 §4 order preserved):
  - **`on_thawed(encounter_id, result)`**, under the reverse wipe: VICTORY resolves the source per `respawn`, grants the first-Victory payoff, writes liberation and removes off-screen linked markers (freeing their cells); FLED stuns and pushes a non-Static symbol (4-connected), or, for a Static story encounter, places the leader at its return marker; followers re-form.
  - **`transition_finished`**: encounter grace starts and Noticing/Chasing symbols switch to Returning (after every transition, the in-mode fade included). On-screen liberation and the payoff card play **only** when `OverworldMode`'s own `pending_thaw` flag (set in `on_thawed`, cleared here) is set, because `transition_finished` carries no transition type.
- Retreat and Quit never thaw (ADR-0002).

**6. Interaction.**
- `confirm` (routed through `handle_action`) calls `probe()`: the nearest **eligible** `Interactable`, `NpcSpawn`, `CampSpot` or `confirm`-started Static symbol within `interact_reach_m` of the probe point (GDD rule 3). The interact prompt draws from the same result.
- An NPC, a gag `line`/`clue` or a decree gag opens `machine.open_overlay(DIALOGUE, payload)`, showing `LocText` verbatim. Until the Dialogue ADR, a **`DialogueStubOverlay` (interim)** shows one line. It is deleted when the Dialogue overlay ships.
- A failed checkpoint's `redirect`/`queue` line ends in `machine.close_overlay()` and then, on the same frame after `overlay_closed`, `machine.request_in_mode_fade(callback)` (ADR-0002 §11); the callback places the leader at the return marker and snaps the camera and followers.
- Pointer input does nothing in the overworld (input GDD rule 3).

**7. Camera, sprites and lighting are ADR-0005's.** Each frame, `OverworldMode` gives `FollowCamera` the party's anchor point. It supplies the bounds once, from the `WalkGrid`. Actors are `CharacterSprite`s. **The lighting profile is resolved before the stage enters the tree**: the map's `liberated_profile_id` when region-liberated, otherwise the `OccupationStageData` profile for the map's faction × stage, otherwise the map's own. The interior travelling light (if ADR-0005 adopts it) exists from the first frame, is never toggled, keeps a fixed shadow flag per profile, and is present when Boot warms the interior materials (probe item 9).

**8. Retiring the interim.** `ChapterMode`'s fixed fight sequence is deleted once one map with one `EncounterSymbol` has a playable Victory, Fled and Defeat loop under Game State (ADR-0002 §8). The chapter's static **step list** (objective text, `{map_id, leg_id}`, scheduled flags) survives as interim data, a `ChapterSteps` resource loaded with the content, until Dialogue, Banter & Quests replaces it (ADR-0002 §8 note). The **current step** is `WorldState.chapter_step`, saved in the `overworld` section, written only by `OverworldMode` (on the chapter's opening step at New Game, and on each step change). The chapter's fights become `enc_` records.

**9. Tuning.** Every value the GDD's Tuning Knobs table lists lives in `OverworldConfig` (project config) or in the records, and the GDD's load-time invariants I1–I18 are checked at boot and in CI by `OverworldConfig.validate()`. `dt_max` is not an `OverworldConfig` field.

### Architecture Diagram

```
GameRoot ─ composition root: WorldState; composite pre_setup injector (ui · presentation_settings · world_state)
  └ ModeHost ─ OverworldMode (GameMode)
       entry: MapEntryPayload → marker (+respawn) | LoadedSave → world_state pos (no respawn) | null → new game
       _ready: MapData → stage + liberation → scene by ID convention → bake WalkGrid (update() once; SAFE; blockers)
               → markers (min_stage, caps) → actors (CharacterSprite) → stage.profile_id (before tree)
       _process(delta):  ow_dt = min(delta, dt_max)   (Exploring only)
          v = machine.get_move_vector(self)                       (ADR-0002/0003)
          leader = GroundMover.step(leader, v, ow_dt, grid, cfg, walk_speed, walls|blocked)
          world_state.party_pos/facing = leader                   (every frame; nothing else per frame)
          exits (enter-edge) → SymbolBrains (shared query budget) → swept contact → probe()
          FollowCamera.target = party anchor                      (processes after OverworldMode)

 start_encounter ─► EncounterDescriptor (enc_) ─► request_transition(BATTLE)   | rejected → contact pending
 Battle → Overworld ─► on_thawed: resolve · payoff · liberation · stun/push or Static return ─► transition_finished: grace · on-screen liberation · payoff card
 redirect ─► request_in_mode_fade(place_at_return_marker)       (same instance; ADR-0002 §11)
 map change ─► request_transition(OVERWORLD, MapEntryPayload): new instance added, then old freed (rollback-safe)
 camp ─► register_camp(id) on passing (ADR-0002 §11) · CAMP with CampEntryPayload on rest
 save (ADR-0009) ─► overworld participant: WorldState (single owner of map + position)
```

### Key Interfaces

```gdscript
## src/overworld/ground_mover.gd — pure, static
class_name GroundMover
static func step(pos: Vector2, input_vec: Vector2, dt: float, grid: WalkGrid, cfg: OverworldConfig,
		speed: float, blocked_mask: int) -> MoveResult

## src/overworld/walk_grid.gd
class_name WalkGrid extends RefCounted
static func bake(layer: TileMapLayer, cell_m: float, safe_sources: Array, cfg: OverworldConfig) -> WalkGrid
func is_walkable(cell: Vector2i) -> bool          # baked walkable and not runtime-blocked
func is_symbol_legal(cell: Vector2i) -> bool      # walkable and not SAFE
func set_blocked(cells: Array[Vector2i], on: bool) -> void   # the only runtime change path; batched; one relabel per frame
func component_of(cell: Vector2i) -> int          # symbol-legal component label
func astar() -> AStarGrid2D                       # pinned config; update() only inside bake
func revision() -> int
func cell_of(ground: Vector2) -> Vector2i
func bounds() -> Rect2                            # ground metres; feeds ADR-0005 follow_camera

## src/overworld/symbol_brain.gd — pure
class_name SymbolBrain extends RefCounted
enum SubState { PATROL, NOTICING, CHASING, RETURNING, STUNNED, STATIC }
func step(dt: float, leader: Vector2, leader_safe: bool, grid: WalkGrid, budget: QueryBudget,
		grace: bool, cfg: OverworldConfig) -> void
func path_dist(leader: Vector2) -> float     # arc to w_last + gap at t0 (+INF if leader was SAFE or gap crosses a non-walkable cell) + leader travel since t0, which the brain accumulates from leader steps
func on_fled(leader: Vector2, leader_facing: Vector2, grid: WalkGrid, cfg: OverworldConfig) -> void
func on_grace_started() -> void                    # Noticing/Chasing → Returning
func contact_eligible() -> bool

## src/overworld/overworld_mode.gd
class_name OverworldMode extends GameMode
var world_state: WorldState                # assigned by the composite pre_setup injector
func start_encounter(enc_id: String, source: EncounterSource) -> void
func on_thawed(encounter_id: String, result: GameStateMachine.BattleResult) -> void
func probe() -> Node                       # eligible target or null; the prompt draws from it

## src/overworld/world_state.gd — injected; never an autoload; single owner of map + position
class_name WorldState extends RefCounted
var map_id: String
var party_pos: Vector2
var party_facing: Vector2
var camp_returns: Dictionary               # camp_id -> { map_id, marker_id }; the return point is derived from machine.last_camp_id
var chapter_step: int                      # interim; only OverworldMode writes it (§8)
func is_resolved(map_id: String, symbol_id: String) -> bool
func mark_resolved(map_id: String, symbol_id: String) -> void
func mark_opened(map_id: String, interact_id: String) -> void
func liberate(map_id: String, marker_ids: PackedStringArray) -> void
func grant_payoff(map_id: String, symbol_id: String) -> bool   # false if already granted
func stage_stored(map_id: String) -> int
func on_map_entered(map_id: String, entry_kind: int, catalog: ContentCatalogService) -> void   # respawn unless Continue
func reset_to_new_game(cfg: OverworldConfig) -> void

## Payloads
class_name MapEntryPayload extends RefCounted
var map_id: String
var entry_marker_id: StringName
class_name CampEntryPayload extends RefCounted   # ADR-0002 annotation
var camp_id: String

## ADR-0002 amendments (d) and (e)
# func request_in_mode_fade(callback: Callable) -> RequestResult
# func register_camp(camp_id: String) -> void

## src/overworld/overworld_config.gd — project config; defaults set by the Overworld GDD Tuning Knobs
class_name OverworldConfig extends Resource
# every knob in the GDD's Tuning Knobs table except dt_max (Presentation's), plus waypoint_tol_m
func validate() -> PackedStringArray       # invariants I1–I18; each error names its ID

## Records (ADR-0001 amendment) — no file paths
class_name MapData extends Resource              # type map, prefix map_
class_name EncounterData extends Resource        # type encounter, prefix enc_
class_name OccupationStageData extends Resource  # type occupation_stage, prefix ostage_
```

### Implementation Guidelines
- The Overworld **must not** use any physics body, area, cast or collision shape, 2D or 3D. `validate_maps.gd` enforces this in CI.
- Movement **must** read only `machine.get_move_vector(self)`, and all logic **must** step on `ow_dt`. **No `Engine.time_scale`.**
- Logic **must** keep positions as ground-plane `Vector2`s, and **must never** read a 3D transform back as the source of truth.
- Blocked cells **must** change only through `WalkGrid.set_blocked()`. `AStarGrid2D.update()` **must** be called only inside the bake.
- Encounters **must** start only through `start_encounter()`. The descriptor **must** come from an `encounter` record.
- Symbol AI **must** live in `SymbolBrain`, pure and steppable without the scene tree; A* queries **must** go through the shared per-frame budget.
- Randomness **must** come from `OverworldMode`'s own seeded `RandomNumberGenerator` (MVP has no random rolls, since `zone_rate = 0`).
- **Ownership:**
  - state that outlives a visit **must** live in `WorldState`, which **must** be the only owner of map and position;
  - `last_camp_id` **must** be written only by the machine, from `CampEntryPayload` or `register_camp()`.
- Records **must not** contain file paths. Map scenes are found by ID convention.
- `stage.profile_id` **must** be set before the stage enters the tree. The mode **must not** request an entry profile in `_ready()`.
- Player-facing text (posters, decrees, cards, barks) **must** be `LocText` (ADR-0013).
- Tuning **must** come from `OverworldConfig` or records, validated by `OverworldConfig.validate()`.
- Test fixtures that build a `TileSet` in code **must** add the source to the `TileSet` before setting custom data (probed).
- **Tests** live in `tests/unit/overworld/` (and `data/` for [D]), with fixture grids, an injected clock and RNG. They cover `GroundMover`, `WalkGrid` (bake, `set_blocked`, components), `SymbolBrain`, `WorldState`, `on_thawed`, `OverworldConfig.validate()`, and `validate_maps` fixtures.

## Alternatives Considered

### Alternative 1: Free-roam with `CharacterBody3D` and 3D collision (Jolt)
- **Description**: `move_and_slide()` against collision meshes on the diorama.
- **Pros**: Arbitrary geometry, slopes and levels.
- **Cons**: Reopens the HIGH Jolt risk; bodies must survive detach; every set needs collision meshes; tests need a physics world.
- **Rejection Reason**: Risk and cost for features the MVP doesn't need.

### Alternative 2: Classic grid stepping
- **Description**: DQ1-style cell-by-cell movement.
- **Pros**: The simplest possible logic.
- **Cons**: Stiff on an analog stick (the Steam Deck is a binding target), and odd on diagonals.
- **Rejection Reason**: Continuous movement on the same grid keeps the simplicity, and `GroundMover` can still step whole cells as a fallback.

### Alternative 3: `CharacterBody2D` on a hidden 2D physics world
- **Description**: GodotPhysics2D with `TileMapLayer` collision.
- **Pros**: Sliding comes from the engine.
- **Cons**: Two worlds to keep in sync; bodies in a detached subtree; tests need the scene tree.
- **Rejection Reason**: A pure mover is easier to test and tune.

### Alternative 4: Encounters configured inline on scene markers
- **Description**: Enemy IDs typed into scene nodes.
- **Pros**: No schema change.
- **Cons**: The IDs escape catalog validation, and balance tooling can't read them.
- **Rejection Reason**: Encounters are content, and content lives in records.

### Alternative 5: A `scene_path` field on `MapData`
- **Description**: The first draft.
- **Pros**: Explicit.
- **Cons**: Breaks Content Data Rule 3.
- **Rejection Reason**: TD review. The ID convention plus a CI existence check does the same job.

### Alternative 6: The redirect as an in-mode fade the Overworld runs itself (rev 3)
- **Description**: `OverworldMode` fades the screen without telling Game State.
- **Pros**: No ADR-0002 change.
- **Cons**: Game State's input lock, Menu deferral, `is_save_safe()` and `transition_finished` (which starts grace) would all miss it.
- **Rejection Reason**: godot-specialist (GDD review 2). A same-instance machine transition (ADR-0002 §11) keeps one owner of transitions.

## Consequences

### Positive
- No physics dependency, so the Jolt risk stays closed. CI enforces it by class.
- Every movement, collision, symbol, encounter and resolution rule is a pure function or plain object, testable headlessly and deterministically.
- Encounters are validated records whose fields are exactly the descriptor's.
- There is one owner of the party's map and position, and one writer of `last_camp_id`.
- Map changes are rollback-safe, and each map applies its stage's or liberated lighting before the first frame.
- Unreachable notice queries cost O(1) through component labels.

### Negative
- Walkability is grid-approximated to `cell_m`. MVP maps are flat.
- Three new record types and a faction field, plus amendments to the Content Data GDD's Rule 1 table, ADR-0002 (map change, `CampEntryPayload`, composite injector, `request_in_mode_fade`, `register_camp`) and ADR-0005 (§4 skip scope, profiles per faction × stage, liberated profile, interior light, blur bounds, capture-ID tags).
- ADR-0009 §3 is revised: map and position move to the Overworld participant.
- `validate_maps.gd` carries many level-design checks and is a real tool to maintain.

## Risks
- **Walls approximated to the grid look wrong.** *Mitigation*: art paints the `WalkLayer` on top of the set; a dev-build overlay draws the baked grid.
- **The corner assist feels slippery.** *Mitigation*: it is a data value, 0 disables it.
- **`AStarGrid2D` cost on the Deck.** *Mitigation*: component labels reject unreachable queries; the notice cache; the shared per-frame budget; the GDD's AC-46 benchmark (chase and fenced-patrol cases) against the 2 ms budget (GDD OQ-19).
- **`AStarGrid2D.update()` silently clears solids** (probed). *Mitigation*: called only inside the bake; a unit test asserts solids survive a `set_blocked` round trip.
- **`validate_maps` grows into a level-design engine.** *Mitigation*: each check is one function with one [D] AC and one failing fixture.
- **A runtime `TileMapLayer` under a `Node3D`.** *Mitigation*: probed inert and freed after the bake.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-scene-flow.md | Rule 5: the Overworld survives battles and is restored exactly; the encounter is then resolved | §4 plain state, position written every frame; §5 two-step thaw |
| game-state-scene-flow.md | Rule 6: the Encounter descriptor's fields | §3 `EncounterData` |
| game-state-scene-flow.md | Rule 9: entering camp records the last camp; leaving returns to that camp's location | §4 `CampEntryPayload`, `register_camp`, `camp_returns` (derived return point) |
| game-state-scene-flow.md | Transitions: Overworld → Battle, Camp and Overworld (map change) | §4, §5, §6 (`request_in_mode_fade`) |
| input-system.md | Rule 3: no pointer in the overworld; `move` as a vector | §2, §6 |
| sprite-camera-presentation.md | `follow_camera`: party target; map bounds from the map's data | §2 bounds from the `WalkGrid`; §7 |
| content-data-definitions.md | Rule 3 (no file paths); Rule 4 (content is records) | §3 |
| overworld-exploration-encounters.md | Rules 0–2: terms, movement, party | §2 `WalkGrid` (SAFE, blockers, components), `GroundMover`; follower trail in `OverworldMode` |
| overworld-exploration-encounters.md | Rules 3–7a: interaction, symbols, contact, thaw, payoffs | §5 `SymbolBrain`, query budget, swept contact, two-step thaw; §6 `probe()` eligibility |
| overworld-exploration-encounters.md | Rules 8–9, 17–18: stages, liberation, liberated presentation, flag registry | §3 `OccupationStageData`, `MapData` stage fields, markers; §4 `WorldState`; §7 profile resolution |
| overworld-exploration-encounters.md | Rules 10–13a, 19: checkpoints, maps, bypass, boss, story encounter, beacon | §3 markers and `validate_maps`; §4 walk home; §6 redirect |
| overworld-exploration-encounters.md | Rule 15 and Edge Cases: save moments, Continue, clock, frame order | §2 clock and order; §4 entry paths |
| overworld-exploration-encounters.md | Formulas I1–I18 | §9 `OverworldConfig.validate()` |

TR IDs for the Overworld GDD rows are assigned by the next `/architecture-review`.

## Performance Implications
- **CPU:**
  - `GroundMover` is O(1) per actor per frame; swept contact is O(symbols);
  - notice tests reject unreachable leaders in O(1) (components) and reuse cached paths; A* queries are capped at `repath_per_frame_max` per frame;
  - the overworld share of the frame budget is **2 ms at p99** for symbol stepping, notice queries and repaths (GDD AC-46; `project.yaml` per-system budget pending, GDD OQ-19).
- **Memory:** about 1 byte per cell for the grid plus a 4-byte component label per cell: about 200 KB for a 200×200 map, plus `AStarGrid2D`'s own per-point storage, roughly 1–2 MB at that size. Still negligible. The detached Overworld stays resident during battles.
- **Load Time:** a single-pass bake plus one component labelling pass inside the fade.

## Migration Plan
1. **Write the Overworld GDD** — done (rev 4, Approved). Run `/architecture-review` and accept this ADR; the ADR-0002 §11 revision and the ADR-0005 annotations take effect with it.
2. **Content Data:** amend the GDD's Rule 1 table (`map`, `encounter`, `occupation_stage`, `faction.patrol_archetype_id`), then add the records.
3. **Pure core, test-first:** `GroundMover`, `WalkGrid` (bake, `set_blocked`, components), `SymbolBrain`, `OverworldConfig.validate()`.
4. **One demo map:**
   - `OverworldMode`, `WorldState`, the composite injector and the encounter pipeline;
   - the ADR-0002 annotations and amendments: fresh-instance map change, `CampEntryPayload`, `request_in_mode_fade`, `register_camp`;
   - the ADR-0005 §4 skip scope and profile resolution.
5. **Retire** `ChapterMode`'s fight sequence (ChapterFlow keeps the step list).
6. **CI and saves:** add `validate_maps.gd` to CI. Add the `overworld` save participant when ADR-0009 lands.
7. **Tooling stories** (GDD "Tooling owed"): the `perf_overworld` map and debug flags, capture-ID tags, the level-review walk-in tool.

## Validation Criteria
- **`GroundMover` unit tests:** frame-rate independence (60 steps of 1/60 s and 30 of 1/30 s end within 1 mm); a wall slide keeps the tangential component; the corner assist passes a one-cell gap; symbols never enter `SAFE` cells.
- **`WalkGrid` unit tests:** `set_blocked` round trip keeps every other solid (guards probe item 5); component labels split and merge correctly; stored paths and the notice cache are invalidated.
- **`SymbolBrain` unit tests:** the GDD's AC-9a–AC-12, AC-17, AC-19a–c, AC-40, AC-40b.
- **Encounter unit tests:** VICTORY resolves the source and grants a payoff once; FLED applies the stun or the Static return; grace starts on `transition_finished`.
- **Integration:** a failed map change rolls back intact; Continue lands at the saved position with no respawn; passing a camp then Retreat lands at that camp; a redirect keeps symbol state and emits `transition_finished`; a Menu-open save captures the current position; the walk home always follows the boss Victory; a map change applies the new map's profile.
- **CI:** `validate_maps.gd` fails on each [D] criterion's failing fixture (a physics node by each listed class, a GridMap with the default layer, a duplicate marker, an unknown `enc_`, a missing map scene, an entry point inside an exit rectangle, a patrol on a stage blocker, a raise triggered by a Victory).
- **Screenshot:** the party walking diagonally past a wall corner on the demo map, retained in `production/qa/evidence/`.

## Related
- **Depends on:** `adr-0001` (amended additively); `adr-0002` (annotated, plus amendments d and e); `adr-0003`; `adr-0004`; `adr-0005` (annotated); `adr-0013`.
- **Uses when available:** `adr-0008-ui-framework.md` (the injector; cards, prompt, Dialogue screens); `adr-0009-save-load-settings.md` (the `overworld` participant; §3 revised to match); `adr-0010-turn-battle-system.md` (`BattleEntryPayload` → `BattleFactory`).
- **Design:** `design/gdd/overworld-exploration-encounters.md` (rev 4, Approved).
- **Upcoming:** the Dialogue, Banter & Quests ADR (NPC payload, global story flags, chapter steps); the Squad Roster ADR (party source); Camp & Party Management.

## Review History
| Date | Reviewer | Verdict | Notes |
|------|----------|---------|-------|
| 2026-10-22 | technical-director (TD-ADR) | CONCERNS → revised | **5 blocking, all fixed:** the `last_camp_id` write path (`CampEntryPayload`); `OVERWORLD → OVERWORLD` vs ADR-0005's same-mode skip (skip scoped to same-instance `BATTLE → BATTLE`; `profile_id` before the tree); fresh-instance swap semantics (rollback-safe); map and position ownership with ADR-0009 (`WorldState` single owner); `MapData.scene_path` vs Content Rule 3 (ID convention + CI). Advisories folded in. |
| 2026-10-22 | godot-specialist | APPROVE | Probed: hidden `TileMapLayer` inert; custom data reads; `AStarGrid2D` API; TileMapLayer property names |
| 2026-10-23 | Overworld GDD reviews 1–2 (ai-programmer, godot-specialist, level-designer) | — (input) | Rev 3 adopts GDD OQ-3 items 0–20: records and markers, `OccupationStageData`, `WorldState` fields, SAFE + blocker overlay + components, `GroundMover` speed/mask/waypoint, pinned A*, swept contact and frame order, query budget, profile resolution, `validate_maps` checks, `OverworldConfig.validate()`, `Engine.time_scale` ban, ADR-0002 amendments (d) `request_in_mode_fade` and (e) `register_camp`, Continue skips respawn, one clock, `SymbolBrain` contract, performance section. Probes 5–9 added |
| 2026-10-23 | Overworld GDD reviews 3–4 | — (input) | Rev 3 text synced to GDD rev 4 (OQ-3 items 21–25): `SymbolBrain` hysteresis, round-robin budget, bounded uniform-cost notice search, final-approach legality, `path_dist` with +∞ gap; 4-connected labels, batched `set_blocked`, frozen `AStarGrid2D` properties; one clock incl. sprites; walk home and last act; probes 10–13 |
| 2026-10-23 | technical-director (TD-ADR) | CONCERNS → revised | **4 blocking, all fixed:** (1) amendment (d) too large for an annotation → written as ADR-0002 §11 revision (`request_in_mode_fade` with legality, zero-length SWAP, two-signal exception, `is_in_mode_fade`; `register_camp`), plus the guideline exception; (2) camp return stored twice → `WorldState.camp_returns` with the return derived from `machine.last_camp_id`; Retreat wording → `choose_retreat()` → CAMP; (3) no owner of the chapter step → `WorldState.chapter_step`, written only by `OverworldMode`, step list as interim `ChapterSteps` data, ADR-0002 §8 note; (4) stale revision references and the decree-gag field. Advisories folded: memory note, ADR-0005 no-rebind line, `register_camp` validation and unsaved progress. Open: OQ-19 per-system budget in `project.yaml` (a schema change, needs the user) and the control-manifest version bump on acceptance |
| 2026-10-23 | godot-specialist (architecture review, delta) | CONCERNS → revised | **G1** (HIGH, PROBED): marker ground positions from local transforms relative to the map root, never `global_*` out of tree. **G2**: `WorldState` committed on `mode_entered`, not in `_ready`. **G3**: map change detaches the old mode first, so `ModeHost` never holds two. **G4**: overlay closed before the fade request; zero-length SWAP; guideline amended. **G5**: `pending_thaw` flag. **G6**: `GameRoot` priority −20. **G7**: deprecated `TileMap` in the class list. **G8**: covered by the derived camp return. Gates: 0005, 0008, 0013 PASS; 0002 PASS with §11 wording |
