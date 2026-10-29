## The Overworld's mode scene root (ADR-0012 §4; ADR-0002 §2). Minimal stub
## for story 001 (AC-1a): wires `machine.get_move_vector(self)` into
## `GroundMover.step()` on the overworld clock, so the control manifest's
## "movement goes through the pure static GroundMover.step(); read input
## only from machine.get_move_vector(self)" rule holds from the first frame
## this mode exists. ADR-0012 §4's full surface -- `world_state`
## (`src/overworld/world_state.gd`), markers, map load, encounters,
## `start_encounter()`, `on_thawed()`, `probe()` -- is each a later story's
## scope; widen this file in place there (same precedent as
## `src/presentation/presentation_config.gd`).
##
## Deviation from ADR-0012 §4, flagged: the leader's position lives in a
## private field here, not in `WorldState`, because `world_state.gd` does not
## exist yet (no story in this epic has created it), and `GameRoot`'s
## `pre_setup` injector does not assign `world_state` or
## `presentation_settings` yet either (both are tagged follow-ups in
## `src/game_state/game_root.gd`, pending ADR-0008/0009). `dt_max` therefore
## falls back to a local constant at the GDD's documented default (0.10 s)
## until `presentation_settings` wiring lands.
class_name OverworldMode
extends GameMode

## GDD Tuning Knobs default for `dt_max` (Presentation's knob; safe range
## 0.05-0.10 s). TODO(ow-epic): replace every use with
## `presentation_settings.dt_max` once ADR-0009's injector exists (see class
## doc) -- `OverworldConfig` must never duplicate this field (ADR-0012 §9).
const _DT_MAX_FALLBACK: float = 0.10

## Tuning for `GroundMover.step()` (ADR-0012 §9). TODO(ow-epic): replace this
## default construction with a catalog/project resource once that pipeline
## exists for the Overworld.
@export var config: OverworldConfig = OverworldConfig.new()

## The map this mode loads in `_ready()` (story 136). Null leaves the mode
## mapless: `GroundMover.step()` then runs with a null grid (no collision),
## the pre-story-136 behaviour every unit test relies on.
@export var map_scene: PackedScene
## Where the instanced map is parented (the stage's set root). Falls back to
## this node when unset.
@export var map_parent: Node3D

## Emitted once when the leader crosses into a `MapExit` (enter edge only).
signal map_exit_requested(exit_id: StringName)

## The GDD States table rows this mode implements so far. EncounterStarting
## is transient inside `start_encounter()`.
enum State { EXPLORING, FROZEN, REDIRECTING }

## GDD Formulas swept contact: below this `|b|^2` the bodies did not move
## relative to each other (a formula constant, not a tuning knob).
const _ZERO_REL_DISPLACEMENT_SQ: float = 1e-8

## Duck-typed record source with `get_record(type, id) -> Resource` (the
## `ContentCatalogService` in the game; injected, never the autoload).
var encounter_catalog: Object = null
## Returns the party (`Array[Combatant]`) for the battle payload.
## TODO(overworld): ChapterFlow's interim party / Squad Roster (ADR-0012 §5).
var party_source: Callable = Callable()
## Persistent state (ADR-0012 §4), assigned by the composite `pre_setup`
## injector. TODO(overworld): GameRoot does not inject it yet; null means
## Victory removes the symbol for this visit only (logged as an error).
var world_state: WorldState = null
## Encounter grace (GDD rule 7): `true` while grace time is left. Started
## only by `transition_finished` (story 047); setting it `true` starts a full
## `config.encounter_grace_s`, `false` ends it.
var grace_active: bool:
	get:
		return _grace_left > 0.0
	set(value):
		_grace_left = config.encounter_grace_s if value else 0.0
## ADR-0012 §5: set in `on_thawed`, cleared on `transition_finished`, so step
## 2 knows the reveal follows a battle (on-screen liberation, payoff card).
var pending_thaw: bool = false
## Diagnostic: how many times grace has started (story 047).
var grace_starts: int = 0
## The symbol whose encounter was accepted, until `transition_finished`.
var pending_source: EncounterSource = null
## Diagnostic: `start_encounter()` calls that reached the machine.
var encounter_requests: int = 0
## Diagnostic: rejections logged (once per contact, story 041).
var rejections_logged: int = 0
## Diagnostic: map-exit requests made (story 040).
var exit_requests: int = 0

var _state: State = State.EXPLORING
var _sources: Array[EncounterSource] = []
var _exit_ids: Array[StringName] = []
var _exit_rects: Array[Rect2] = []
# Story 138: per exit, its map-change target (null for a test-only exit).
var _exit_targets: Array[MapEntryPayload] = []
# Story 138: the entry payload this instance was set up with, or null.
var _entry_payload: MapEntryPayload = null
var _budget: QueryBudget = null

var _machine: GameStateMachine = null

## Seconds of encounter grace left (advanced only by `step_frame`).
var _grace_left: float = 0.0
## Exploring is suspended while any of these hold (story 048; GDD States).
var _overlays_open: int = 0
var _transitioning: bool = false
var _camp_prompt_open: bool = false
## Runs on the same frame as the open line's `overlay_closed` (`say()`).
var _after_line: Callable = Callable()
## A line to open automatically on the next reveal (rule 13a Fled).
var _line_on_reveal: String = ""
## Flags kept for the visit when there is no `world_state` (tests).
var _flags_this_visit: Dictionary = {}
## Every line opened through `say()`, in order (tests read it).
var lines_said: Array[String] = []
## The follow camera's settings, for the first-sight check (rule 13a); the
## view assigns its own on start.
var presentation: PresentationConfig = PresentationConfig.new()

## The leader was placed outside walking (map entry, teleport, redirect,
## thaw): followers re-formed and the camera snaps (GDD rule 2, rule 10).
signal party_placed(at: Vector2)
## A `confirm`-started Static symbol barked on first touch (rule 13a).
signal barked(text: String, at: Vector2)
## The CampSpot the open prompt belongs to.
var _camp_prompt_camp: CampSpot = null
## The CampSpot whose safe zone the leader stood in last frame.
var _camp_zone: CampSpot = null
## This map's checkpoints by `marker_id`.
var _checkpoints: Dictionary = {}
## Checkpoints opened this visit (used when there is no `world_state`).
var _opened_this_visit: Dictionary = {}

## Choices on the "Rest here?" prompt. Yes has the default focus (UI
## Requirements: the player already chose to press `confirm` on the camp).
enum CampChoice { YES, NO }

## The prompt's focused choice while it is open.
var camp_prompt_focus: CampChoice = CampChoice.YES
## Camp requests issued from the prompt (tests read it).
var camp_requests: int = 0
## The leader's facing: the last non-zero input direction (ADR-0012 §4
## `party_facing`; the flee push's coincident-centres fallback).
var _leader_facing: Vector2 = Vector2.DOWN

## The loaded map and its baked grid (ADR-0012 §2: baked once, at load).
var _map: OverworldMap = null
var _grid: WalkGrid = null

## TODO(ow-epic): moves to `WorldState.party_pos` once that type exists
## (ADR-0012 §4); story 001 only proves `GroundMover`'s formula end to end.
var _leader_pos: Vector2 = Vector2.ZERO

## The most recent `GroundMover.step()` call's `distance_moved`, read by
## `get_last_distance_moved()`. Exists so a test can derive this frame's
## leader speed (`distance_moved / dt`) through the real `_process()` call
## path (story 003, AC-1c) instead of reaching into `_leader_pos`.
var _last_distance_moved: float = 0.0

## Cosmetic follower positions only (GDD rule 2: "Followers have no
## collision and no logic, and nothing can touch them"; ADR-0012 §2 settles
## the point left open -- only the leader has a position in logic). Set by
## `step_followers()` (story 006's trail-spacing formula); story 005 proved
## the array's isolation from `_process()`, which still never reads or
## writes it directly -- only `step_followers()` does, and only when a
## caller invokes it. Positions only, no `CharacterSprite`s (those are
## story 007's scope, ADR-0012 §4 step 5); this is the seam stories 007-010
## extend.
var _follower_positions: Array[Vector2] = []

## The follower-trail replay (GDD Formulas, `follower_trail`). Owns its own
## recorded-point buffer across frames; `step_followers()` is the only
## caller in normal walking; `_reform_followers()` snaps it on map entry,
## teleport, redirect and thaw (story 007).
var _follower_trail: FollowerTrail = FollowerTrail.new()

## Set by `load_map()` during a transition: the `WorldState` entry and the
## symbol placement wait for `mode_entered(OVERWORLD)` (`_commit_map_entry()`).
var _entry_commit_pending: bool = false


func _init() -> void:
	# Pinned ordering (ADR-0012 §2): GameRoot -20, OverworldMode -10,
	# FollowCamera 0, CharacterSprite +10. process_priority sorts globally,
	# regardless of tree order (probed, 4.7.2).
	process_priority = -10


func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	if payload is MapEntryPayload:
		_entry_payload = payload as MapEntryPayload
	if machine == null:
		return
	_transitioning = machine.phase != GameStateMachine.Phase.IDLE
	if not machine.transition_finished.is_connected(_on_transition_finished):
		machine.transition_finished.connect(_on_transition_finished)
		machine.transition_started.connect(_on_transition_started)
		machine.overlay_opened.connect(_on_overlay_opened)
		machine.overlay_closed.connect(_on_overlay_closed)
		machine.mode_entered.connect(_on_mode_entered)


## Story 138: a `MapEntryPayload` loads its map by the scene-path
## convention and places the party at its EntryPoint; otherwise (New Game)
## the exported `map_scene` at its spawn cell.
func _ready() -> void:
	if _map != null:
		return
	if _entry_payload != null:
		var path: String = OverworldMap.scene_path(_entry_payload.map_id, config.map_scene_dir)
		var scene: PackedScene = ResourceLoader.load(path) as PackedScene if ResourceLoader.exists(path) else null
		if scene == null:
			push_error("OverworldMode: no map scene at %s" % path)
			return
		load_map(scene.instantiate() as OverworldMap, _entry_payload.entry_marker_id)
	elif map_scene != null:
		load_map(map_scene.instantiate() as OverworldMap)


## Loads `map` (story 136; ADR-0012 §2): parents it under `map_parent` if it
## has no parent yet, bakes its `WalkGrid` once, builds the set geometry,
## places the leader on the map's spawn cell and re-anchors the follower
## trail there. Story 138: with `entry_marker_id`, the leader starts at that
## EntryPoint facing its `facing`, followers snap into formation behind it
## (story 007's rule), and the map's `MapExit` markers are registered.
func load_map(map: OverworldMap, entry_marker_id: StringName = &"") -> void:
	if map == null:
		push_error("OverworldMode: load_map() given a null or non-OverworldMap scene")
		return
	_map = map
	if map.get_parent() == null:
		(map_parent if map_parent != null else self).add_child(map)
	_grid = map.bake_walk_grid(config)
	map.build_set(_grid)
	_setup_checkpoints(map)
	_leader_pos = map.spawn_position(_grid)
	var entry: EntryPoint = map.find_entry_point(entry_marker_id) \
			if entry_marker_id != &"" else null
	if entry_marker_id != &"" and entry == null:
		push_error("OverworldMode: %s has no EntryPoint '%s'" % [map.map_id, entry_marker_id])
	if entry != null:
		_leader_pos = entry.ground_position(map)
		if not entry.facing.is_zero_approx():
			_leader_facing = entry.facing.normalized()
	_reform_followers()
	for exit: MapExit in map.map_exits():
		add_map_exit(exit.marker_id, exit.trigger_rect,
				MapEntryPayload.new(exit.target_map_id, exit.target_entry_id))
	# ADR-0012 §2 (architecture review G2): during a transition nothing is
	# written to `WorldState` until `mode_entered(OVERWORLD)`, after the swap
	# has succeeded, so a rolled-back map change leaves it on the old map.
	# Symbols wait too: which are resolved depends on that commit.
	if _machine != null and _machine.phase != GameStateMachine.Phase.IDLE:
		_entry_commit_pending = true
	else:
		_commit_map_entry()


## Records the map entry in `WorldState` (respawning per policy) and places
## this map's symbols: on `mode_entered(OVERWORLD)` during a transition, at
## once when `load_map()` runs outside one (tests, the demo scene).
func _commit_map_entry() -> void:
	_entry_commit_pending = false
	if world_state != null and world_state.map_id != _map.map_id:
		world_state.on_map_entered(_map.map_id, WorldState.EntryKind.MAP_ENTRY)
	_place_symbols(_map)


## Commits a pending map entry once the swap has succeeded. A node no longer
## in the tree is a map change's replaced or rolled-back instance, still
## connected until it is freed at the end of the frame; it never commits.
func _on_mode_entered(to: GameStateMachine.Mode) -> void:
	if to == GameStateMachine.Mode.OVERWORLD and _entry_commit_pending and is_inside_tree():
		_commit_map_entry()


## `true` when this Overworld has no map: its scene was missing, so a map
## change into it must roll back (`ModeHostSceneLoader`, ADR-0012 §2).
func swap_failed() -> bool:
	return _map == null


## Story 137: one `SymbolBrain` per valid `EncounterSymbol` marker, in
## marker order. `add_symbol()` skips symbols `world_state` holds resolved.
func _place_symbols(map: OverworldMap) -> void:
	var markers: Array[EncounterSymbol] = map.symbol_markers()
	for i: int in markers.size():
		var marker: EncounterSymbol = markers[i]
		if not marker.is_valid_marker():
			push_error("OverworldMode: symbol marker '%s' names no enc_ record or has no patrol path" \
					% marker.name)
			continue
		var source: EncounterSource = add_symbol(marker.encounter_id,
				SymbolBrain.new(marker.patrol_path, marker.path_mode, i), marker.symbol_id)
		if source != null and marker.is_static:
			source.brain.make_static(marker.start_on == EncounterSymbol.StartOn.CONTACT_OR_CONFIRM)
			source.checkpoint_id = marker.checkpoint_id
			source.return_marker = marker.return_marker
			source.return_facing = (marker.return_marker - marker.patrol_path[0]).normalized()
			source.bark_line = marker.bark_line
			source.fled_line = marker.fled_line


## The baked walk grid, or null while no map is loaded.
func get_walk_grid() -> WalkGrid:
	return _grid


## The loaded map, or null while no map is loaded.
func get_map() -> OverworldMap:
	return _map


## No discrete action is handled yet (routing lands in story 010+); always
## falls through so a later `handle_action` override is additive, not a
## rewrite. This call path never reads or writes `_leader_pos` -- AC-1c's own
## proof that `confirm`/`cancel`/`menu` cannot change the leader's speed,
## however they're driven (pressed or held), since `handle_action()` and the
## movement step in `_process()` never share state
## (`tests/unit/overworld/ground_mover_speed_test.gd`).
func handle_action(action: StringName, pressed: bool) -> bool:
	if _camp_prompt_open:
		return _handle_camp_prompt(action, pressed)
	if action != InputActions.CONFIRM or not pressed or not is_exploring():
		return false
	confirm()
	return true


## Reads movement only through `machine.get_move_vector(self)` (control
## manifest; ADR-0012 §2) and steps on `ow_dt = min(delta, dt_max)`. Never
## branches on a discrete action first (AC-1c) -- this function has no way to
## see one; `handle_action()` is the only call path actions arrive through.
func _process(delta: float) -> void:
	if _machine == null:
		return
	var ow_dt: float = minf(delta, _DT_MAX_FALLBACK)
	step_frame(ow_dt, _machine.get_move_vector(self))


## One Exploring frame in ADR-0012 §5's fixed order: move the leader (corner
## assist on, leader only) -> check map exits (enter-edge; an exit request
## ends the frame, so contact is never checked on it -- GDD Edge Cases,
## story 040) -> step symbols in marker order under the shared query budget
## -> swept contact, eligibility read after the steps (stories 038, 041,
## 042). TODO(overworld): interaction requests (step 5). Does nothing
## outside Exploring (Frozen while the battle request is accepted).
func step_frame(ow_dt: float, input_vec: Vector2) -> void:
	if not is_exploring():
		return
	# Grace runs on `ow_dt` only (ADR-0012 §2), ticked before contact reads it.
	_grace_left = maxf(0.0, _grace_left - ow_dt)
	if not input_vec.is_zero_approx():
		_leader_facing = input_vec.normalized()
	var leader_from: Vector2 = _leader_pos
	var result: GroundMover.MoveResult = GroundMover.step(
			_leader_pos, input_vec, ow_dt, _grid, config, config.walk_speed, 0, true)
	_leader_pos = result.position
	_last_distance_moved = result.distance_moved
	if _check_exits(leader_from, _leader_pos):
		return
	_check_camp_registration()
	_check_barks_and_sight()
	if _budget == null:
		_budget = QueryBudget.new(config.repath_per_frame_max)
	_budget.begin_frame()
	var symbol_from: Array[Vector2] = []
	for source: EncounterSource in _sources:
		symbol_from.append(source.brain.position)
		if _grid != null:
			source.brain.step(ow_dt, _leader_pos, _grid, grace_active, config, _budget)
	_check_contact(leader_from, symbol_from)


## Registers an encounter symbol (ADR-0012 §5): `enc_id` names its
## `encounter` record and `brain` its AI. Kept sorted by
## `brain.marker_index` (stable), which is the step order and the contact
## tie-break order (GDD Edge Cases).
##
## Story 043: a symbol `world_state` holds resolved on the current map is not
## registered (absent for the visit); returns null then. `symbol_id`
## defaults to `enc_id`.
func add_symbol(enc_id: String, brain: SymbolBrain, symbol_id: String = "") -> EncounterSource:
	var source := EncounterSource.new(enc_id, brain, symbol_id)
	if world_state != null and world_state.is_resolved(world_state.map_id, source.symbol_id):
		return null
	var at: int = _sources.size()
	for i in _sources.size():
		if _sources[i].brain.marker_index > brain.marker_index:
			at = i
			break
	_sources.insert(at, source)
	return source


## Registers a `MapExit` rectangle in ground metres. Crossing into it (enter
## edge only) requests the exit via `map_exit_requested`.
func add_map_exit(exit_id: StringName, rect: Rect2, target: MapEntryPayload = null) -> void:
	_exit_ids.append(exit_id)
	_exit_rects.append(rect)
	_exit_targets.append(target)


## Injects a baked walk grid without a map scene (tests, ADR-0012 §2).
func set_walk_grid(grid: WalkGrid) -> void:
	_grid = grid


## Places the leader (map entry, tests). Re-anchors the follower trail.
func set_leader_position(pos: Vector2) -> void:
	_leader_pos = pos
	_follower_trail.reset(pos)


## A scripted teleport (story 007, GDD Edge Cases): places the leader at
## `pos`, facing `facing` if it is non-zero, and snaps the followers into
## formation behind it on this same call.
func teleport_leader(pos: Vector2, facing: Vector2 = Vector2.ZERO) -> void:
	_leader_pos = pos
	if not facing.is_zero_approx():
		_leader_facing = facing.normalized()
	_reform_followers()


## A checkpoint redirect (story 007; ADR-0012 §6, ADR-0002 §11): requests
## the same-instance in-mode fade, whose callback teleports the leader to
## `pos` behind the fade and re-forms the followers there. Closing the
## checkpoint's Dialogue first, the camera snap and the `WorldState` write
## belong to the checkpoint-outcome story (072); this is the follower half.
func redirect_leader(pos: Vector2, facing: Vector2 = Vector2.ZERO) -> GameStateMachine.RequestResult:
	if _machine == null:
		push_error("OverworldMode: redirect_leader() with no GameStateMachine")
		return GameStateMachine.RequestResult.REJECTED_INVALID_PAYLOAD
	var result: GameStateMachine.RequestResult = _machine.request_in_mode_fade(
			teleport_leader.bind(pos, facing))
	if result == GameStateMachine.RequestResult.OK:
		_state = State.REDIRECTING
	return result


## The one routine every position reset outside walking funnels into (story
## 007, GDD rule 2 and Edge Cases; ADR-0012 §4/§6): map entry, teleport,
## redirect and battle thaw. Clears the trail and fills it behind the
## leader, opposite its facing, over walkable cells only, so on this frame
## the followers sit at spacing in formation; where a wall cuts the walk
## short the remaining followers share the last walkable point
## (`FollowerTrail.snap()`).
func _reform_followers() -> void:
	_follower_trail.snap(_leader_pos, _leader_facing, config.max_followers, config, _grid)
	_follower_positions = _follower_trail.step(_leader_pos, config.max_followers, config)
	party_placed.emit(_leader_pos)


## The registered encounter sources (symbol + record id), in marker order
## (story 137: GameRoot tests and the view read them).
func get_encounter_sources() -> Array[EncounterSource]:
	return _sources.duplicate()


## The registered symbols' brains, in marker order.
func get_symbol_brains() -> Array[SymbolBrain]:
	var brains: Array[SymbolBrain] = []
	for source: EncounterSource in _sources:
		brains.append(source.brain)
	return brains


## The mode's state (`EXPLORING` or `FROZEN`).
func get_state() -> State:
	return _state


## ADR-0012 §5 `start_encounter(enc_id, source)`: builds the descriptor from
## the `encounter` record, builds the `BattleEntryPayload`, remembers
## `pending_source` and calls `machine.request_transition(Mode.BATTLE, ...)`.
## Accepted -> Frozen. Rejected -> the touched symbol is held in contact
## pending and contact is retried next frame; the rejection is logged once
## per contact (GDD Edge Cases). Returns the machine's result (ADR-0012's
## signature returns `void`; the result is returned for callers and tests).
func start_encounter(enc_id: String, source: EncounterSource) -> GameStateMachine.RequestResult:
	var rec: EncounterData = null
	if encounter_catalog != null:
		rec = encounter_catalog.get_record(&"encounter", enc_id) as EncounterData
	if rec == null or _machine == null:
		push_error("OverworldMode: no encounter record '%s' (or no machine)" % enc_id)
		return GameStateMachine.RequestResult.REJECTED_INVALID_PAYLOAD
	var payload := BattleEntryPayload.new()
	payload.descriptor = build_descriptor(rec)
	if party_source.is_valid():
		payload.party.assign(party_source.call())
	source.brain.on_contact()
	encounter_requests += 1
	var result: GameStateMachine.RequestResult = _machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	if result == GameStateMachine.RequestResult.OK:
		source.brain.contact_pending = false
		pending_source = source
		_state = State.FROZEN
		return result
	if not source.brain.contact_pending:
		rejections_logged += 1
		push_warning("OverworldMode: start_encounter('%s') rejected (%d); contact pending" \
				% [enc_id, result])
	source.brain.contact_pending = true
	return result


## Copies an `encounter` record into a fresh `EncounterDescriptor`, field for
## field (ADR-0012 §3: the record's fields are exactly the descriptor's).
static func build_descriptor(rec: EncounterData) -> EncounterDescriptor:
	var d := EncounterDescriptor.new()
	d.encounter_id = rec.id
	d.enemy_ids = rec.enemy_ids.duplicate()
	d.battle_stage_id = rec.battle_stage_id
	d.faction_id = rec.faction_id
	d.is_boss = rec.is_boss
	d.can_flee = rec.can_flee
	d.retreat_allowed = rec.retreat_allowed
	return d


## GDD Formulas `frame_step_safety`, swept contact: the closest approach of
## the leader and a symbol over one frame, `min over t in [0, 1] of
## |a + t*b|` with `a = c_L0 - c_S0` and `b = d_L - d_S`; `|a|` when
## `|b|^2 < 1e-8` (no division).
static func closest_approach(leader_from: Vector2, leader_delta: Vector2,
		symbol_from: Vector2, symbol_delta: Vector2) -> float:
	var a: Vector2 = leader_from - symbol_from
	var b: Vector2 = leader_delta - symbol_delta
	var bb: float = b.length_squared()
	if bb < _ZERO_REL_DISPLACEMENT_SQ:
		return a.length()
	var t: float = clampf(-a.dot(b) / bb, 0.0, 1.0)
	return (a + b * t).length()


func _check_exits(from: Vector2, to: Vector2) -> bool:
	for i in _exit_rects.size():
		if not _exit_rects[i].has_point(from) and _exit_rects[i].has_point(to):
			exit_requests += 1
			map_exit_requested.emit(_exit_ids[i])
			_request_map_change(_exit_targets[i])
			return true
	return false


## Story 138 (ADR-0012 §4): asks Game State for the `OVERWORLD -> OVERWORLD`
## fresh-instance map change. A rejected request leaves the leader in the
## rectangle; it fires again only after leaving and re-entering (story 081).
func _request_map_change(target: MapEntryPayload) -> void:
	if target == null or _machine == null:
		return
	var result: GameStateMachine.RequestResult = _machine.request_transition(
			GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new(target.map_id, target.entry_marker_id))
	if result != GameStateMachine.RequestResult.OK:
		rejections_logged += 1


## GDD rule 5 Contact + Edge Cases: among eligible symbols whose swept
## closest approach is <= 2 * body_radius, the smallest distance wins, ties
## to the earlier marker; one `start_encounter` per frame. A contact-pending
## symbol whose overlap ended is released.
func _check_contact(leader_from: Vector2, symbol_from: Array[Vector2]) -> void:
	var leader_delta: Vector2 = _leader_pos - leader_from
	var leader_safe: bool = _grid != null and _grid.is_safe(_grid.cell_of(_leader_pos))
	var reach: float = 2.0 * config.body_radius
	var best: EncounterSource = null
	var best_d: float = INF
	for i in _sources.size():
		var source: EncounterSource = _sources[i]
		var touching: bool = false
		var d: float = INF
		if not grace_active and not leader_safe and source.brain.contact_eligible():
			d = closest_approach(leader_from, leader_delta, symbol_from[i],
					source.brain.position - symbol_from[i])
			touching = d <= reach
		if not touching:
			source.brain.contact_pending = false
			continue
		if d < best_d:
			best = source
			best_d = d
	if best != null:
		start_encounter(best.enc_id, best)


## `true` only in Exploring (story 048; GDD States): not Frozen, no overlay
## (Menu, Dialogue), no CampPrompt and no transition running. Every symbol
## and grace timer advances only inside `step_frame`, which does nothing
## otherwise, so they all freeze together. No `Engine.time_scale`.
func is_exploring() -> bool:
	return _state == State.EXPLORING and _overlays_open == 0 and not _transitioning \
			and not _camp_prompt_open


## The CampPrompt state (GDD States: "Rest here?"), set directly by tests;
## the game opens it through `confirm()` at a CampSpot (story 113).
func set_camp_prompt_open(open: bool) -> void:
	_camp_prompt_open = open


## Seconds of encounter grace left.
func get_grace_left() -> float:
	return _grace_left


## The leader's facing (unit vector).
func get_leader_facing() -> Vector2:
	return _leader_facing


## Sets the leader's facing (map entry, tests). A zero vector is ignored.
func set_leader_facing(facing: Vector2) -> void:
	if not facing.is_zero_approx():
		_leader_facing = facing.normalized()


## ADR-0002 §4 / ADR-0012 §5 step 1, under the reverse wipe, after
## `mode_entered(OVERWORLD)`: VICTORY resolves the source per its record's
## respawn policy in `world_state` and removes it for this visit (story
## 043); FLED stuns and pushes it (story 044). The leader never moves;
## followers re-form behind it. Grace is NOT started here (story 047).
## TODO(overworld): the payoff (story 050), liberation (052) and the Static
## Fled return marker.
func on_thawed(encounter_id: String, result: GameStateMachine.BattleResult) -> void:
	var source: EncounterSource = pending_source
	if source == null or source.enc_id != encounter_id:
		source = null
		for s: EncounterSource in _sources:
			if s.enc_id == encounter_id:
				source = s
				break
	if source == null:
		push_warning("OverworldMode: on_thawed('%s') has no source symbol" % encounter_id)
		return
	pending_thaw = true
	match result:
		GameStateMachine.BattleResult.VICTORY:
			if _sources.has(source):
				_resolve_victory(source)
			# Rule 10 `encounter` outcome and rule 13a: winning opens the checkpoint.
			if source.checkpoint_id != &"":
				open_checkpoint(source.checkpoint_id)
		GameStateMachine.BattleResult.FLED:
			source.brain.on_fled(_leader_pos, _leader_facing, _grid, config)
			# Rule 13a: Fled places the squad at the return marker, under the wipe.
			if source.return_marker != Vector2.ZERO:
				_leader_pos = source.return_marker
				if not source.return_facing.is_zero_approx():
					_leader_facing = source.return_facing.normalized()
				_line_on_reveal = source.fled_line
	_reform_followers()


func _resolve_victory(source: EncounterSource) -> void:
	var rec: EncounterData = null
	if encounter_catalog != null:
		rec = encounter_catalog.get_record(&"encounter", source.enc_id) as EncounterData
	if world_state == null:
		push_error("OverworldMode: no world_state; '%s' resolved for this visit only" % source.symbol_id)
	else:
		world_state.mark_resolved(world_state.map_id, source.symbol_id, WorldState.respawn_of(rec))
	_sources.erase(source)


func _on_transition_started(_from: GameStateMachine.Mode, _to: GameStateMachine.Mode) -> void:
	_transitioning = true


func _on_overlay_opened(_kind: GameStateMachine.OverlayKind) -> void:
	_overlays_open += 1


func _on_overlay_closed(kind: GameStateMachine.OverlayKind) -> void:
	_overlays_open = maxi(0, _overlays_open - 1)
	# ADR-0012 §6: a checkpoint's redirect follows its line on the same frame
	# as `overlay_closed`.
	if kind == GameStateMachine.OverlayKind.DIALOGUE and _after_line.is_valid():
		var then: Callable = _after_line
		_after_line = Callable()
		then.call()


## ADR-0012 §5 step 2, `transition_finished` once the scene is revealed:
## back to Exploring, encounter grace starts (`config.encounter_grace_s`,
## story 047) and Noticing/Chasing symbols switch to Returning (GDD rule 7).
## Fires after a battle thaw, any map load and a redirect alike.
func _on_transition_finished(to: GameStateMachine.Mode) -> void:
	_transitioning = false
	if to != GameStateMachine.Mode.OVERWORLD:
		return
	_state = State.EXPLORING
	pending_source = null
	pending_thaw = false
	_grace_left = config.encounter_grace_s
	grace_starts += 1
	for source: EncounterSource in _sources:
		source.brain.on_grace_started()
	# Rule 13a: after Fled from the story encounter, its line opens as an
	# automatic Dialogue on the reveal, guarded against a held confirm.
	if not _line_on_reveal.is_empty():
		var line: String = _line_on_reveal
		_line_on_reveal = ""
		say(line)


## This frame's `distance_moved` from the last `_process()` step, so a test
## can derive leader speed as `get_last_distance_moved() / dt` (AC-1c)
## without reading `_leader_pos` directly.
func get_last_distance_moved() -> float:
	return _last_distance_moved


## The leader's current ground-plane position (ADR-0012 §2). Story 006's
## trail-spacing formula is the intended first caller -- it places each
## follower relative to the leader's position (and, later, its recent
## path) -- so this getter exists from story 005 rather than being added
## alongside the formula itself.
func get_leader_position() -> Vector2:
	return _leader_pos


## Replaces the cosmetic follower positions (story 005, AC-3; GDD rule 2).
## Story 006's trail-spacing formula is the only intended caller once it
## lands -- nothing calls this yet, so `_follower_positions` stays empty by
## default. Positions only; building the `CharacterSprite`s that render them
## is story 007's scope (ADR-0012 §4 step 5). Duplicates `positions` so the
## caller's array and this mode's copy never alias.
func set_follower_positions(positions: Array[Vector2]) -> void:
	_follower_positions = positions.duplicate()


## The cosmetic follower positions last set by `set_follower_positions()`
## or `step_followers()` (empty until one of them is called). Returns a
## duplicate so the caller can never mutate this mode's own copy through
## the returned array. `_process()` itself never calls this (story 005,
## AC-3) -- only rendering (story 007+) and `step_followers()` are meant to.
func get_follower_positions() -> Array[Vector2]:
	return _follower_positions.duplicate()


## Drives the follower trail for this frame (GDD Formulas,
## `follower_trail`; ADR-0012 §2) and refreshes `_follower_positions` to
## `n_followers` cosmetic positions, nearest follower first, replaying
## `get_leader_position()`'s recorded path at `config`'s spacing and sample
## knobs. A separate call from `_process()`, not a step inside it -- GDD
## rule 2 and story 005's `follower_no_collision_test.gd` fix `_process()`'s
## own behaviour as leader-movement only, and no roster exists yet (story
## 008/010) to supply `n_followers` automatically, so the caller (today, a
## test; later, whichever system holds the roster) passes it explicitly and
## calls this once per frame alongside `_process()`.
func step_followers(n_followers: int) -> void:
	set_follower_positions(_follower_trail.step(_leader_pos, n_followers, config))


# -- Checkpoints (GDD rule 10; stories 070-072) ------------------------------

## Registers `map`'s checkpoints: one already opened in `world_state` stays
## open; every other one blocks its cells (rule 0 "Blocked cell").
func _setup_checkpoints(map: OverworldMap) -> void:
	_checkpoints.clear()
	_opened_this_visit.clear()
	for cp: CheckpointMarker in map.checkpoints():
		add_checkpoint(cp)


## Registers checkpoint `cp` on the current map (load, tests): closed
## unless `world_state` holds it open, in which case its cells stay free.
func add_checkpoint(cp: CheckpointMarker) -> void:
	_checkpoints[cp.marker_id] = cp
	if not is_checkpoint_open(cp.marker_id) and _grid != null:
		_grid.set_blocked(checkpoint_cells(cp, _grid), true)
	elif _map != null:
		_map.set_checkpoint_shown(cp.marker_id, false)


## The grid cells `cp.blocked_rect` covers (any overlap counts).
static func checkpoint_cells(cp: CheckpointMarker, grid: WalkGrid) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r: Rect2 = cp.blocked_rect
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return out
	var lo := Vector2i(floori(r.position.x / grid.cell_m), floori(r.position.y / grid.cell_m))
	var hi := Vector2i(ceili(r.end.x / grid.cell_m) - 1, ceili(r.end.y / grid.cell_m) - 1)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			out.append(Vector2i(x, y))
	return out


## `true` once checkpoint `marker_id` on this map is open.
func is_checkpoint_open(marker_id: StringName) -> bool:
	if not _checkpoints.has(marker_id):
		return false
	if world_state != null:
		return world_state.is_checkpoint_open(_map_id(), marker_id)
	return _opened_this_visit.has(marker_id)


## Opens checkpoint `marker_id` for good (rule 10 Success; the `encounter`
## outcome's Victory): frees its cells and records it in `world_state`.
func open_checkpoint(marker_id: StringName) -> void:
	var cp: CheckpointMarker = _checkpoints.get(marker_id) as CheckpointMarker
	if cp == null:
		push_error("OverworldMode: no checkpoint '%s' on this map" % marker_id)
		return
	if is_checkpoint_open(marker_id):
		return
	_opened_this_visit[marker_id] = true
	if _map != null:
		_map.set_checkpoint_shown(marker_id, false)
	if world_state != null:
		world_state.open_checkpoint(_map_id(), marker_id)
	if _grid != null:
		_grid.set_blocked(checkpoint_cells(cp, _grid), false)


## `confirm` at checkpoint `marker_id` (rule 10). A met requirement opens
## it. Otherwise the failure outcome plays: `encounter` starts the linked
## fight (story 072), whose Victory opens it; `redirect` and `queue` send
## the leader to the return marker (story 071 adds their Dialogue line).
func confirm_checkpoint(marker_id: StringName) -> void:
	var cp: CheckpointMarker = _checkpoints.get(marker_id) as CheckpointMarker
	if cp == null or is_checkpoint_open(marker_id):
		return
	if _requirement_met(cp):
		open_checkpoint(marker_id)
		return
	match cp.failure_outcome:
		CheckpointMarker.FailureOutcome.ENCOUNTER:
			start_encounter(cp.linked_encounter_id, checkpoint_source(cp, _map))
		_:
			# Story 071: the line, then on the same frame as its close the
			# input-locked redirect to the return marker. `queue` differs only
			# in its line; neither waits on a timed or held input.
			say(_failure_line(cp), redirect_leader.bind(cp.return_marker, cp.return_facing))


## The encounter source a checkpoint's `encounter` outcome fights from: a
## Static, contact-free stand-in at the checkpoint, never stepped or
## touched, that opens `cp` on Victory and returns to its marker on Fled.
static func checkpoint_source(cp: CheckpointMarker, map: OverworldMap) -> EncounterSource:
	var at: Vector2 = cp.ground_position(map) if map != null else cp.return_marker
	var brain := SymbolBrain.new(PackedVector2Array([at]), SymbolBrain.PathMode.LOOP, -1)
	brain.make_static(false)
	var source := EncounterSource.new(cp.linked_encounter_id, brain,
			"checkpoint_" + String(cp.marker_id))
	source.checkpoint_id = cp.marker_id
	source.return_marker = cp.return_marker
	source.return_facing = cp.return_facing
	return source


## Rule 10: exactly one requirement, an item or a story flag. Flags read
## `world_state`. TODO(overworld): items, once an inventory exists.
func _requirement_met(cp: CheckpointMarker) -> bool:
	if not cp.requirement_flag.is_empty():
		return world_state != null and world_state.has_flag(cp.requirement_flag)
	return false


func _map_id() -> String:
	return _map.map_id if _map != null else ""


# -- Interaction (GDD rule 3) -----------------------------------------------

## The nearest eligible target within `interact_reach_m` of the probe point
## (`facing * body_radius` ahead of the leader), or null (GDD rule 3).
## Targets: CampSpots (always eligible), Static symbols (eligible while
## unresolved) and closed checkpoints, except a story encounter's own
## checkpoint while its Static symbol stands. Exact ties go CampSpot, then
## Static symbol, then checkpoint. Returns a `CampSpot`, an
## `EncounterSource` or a `CheckpointMarker`. TODO(overworld): NPCs and
## gags (stories 011-016).
func probe() -> Object:
	var point: Vector2 = _leader_pos + _leader_facing.normalized() * config.body_radius
	var best: Object = null
	var best_d: float = INF
	var reach: float = config.interact_reach_m + 1e-6
	if _map != null:
		for camp: CampSpot in _map.camp_spots():
			var d: float = point.distance_to(camp.ground_position(_map))
			if d <= reach and d < best_d:
				best = camp
				best_d = d
	var guarded: Dictionary = {}
	for source: EncounterSource in _sources:
		if not source.brain.is_static():
			continue
		if source.checkpoint_id != &"":
			guarded[source.checkpoint_id] = true
		var d: float = point.distance_to(source.brain.position)
		if d <= reach and d < best_d:
			best = source
			best_d = d
	for marker_id: StringName in _checkpoints:
		var cp: CheckpointMarker = _checkpoints[marker_id]
		if is_checkpoint_open(marker_id) or guarded.has(marker_id):
			continue
		var d: float = point.distance_to(cp.ground_position(_map))
		if d <= reach and d < best_d:
			best = cp
			best_d = d
	return best


## `confirm` in Exploring acts on `probe()`'s result (GDD rule 3). Nothing
## in reach does nothing.
func confirm() -> void:
	var target: Object = probe()
	if target is CampSpot:
		_open_camp_prompt(target as CampSpot)
	elif target is EncounterSource:
		var source: EncounterSource = target
		start_encounter(source.enc_id, source)
	elif target is CheckpointMarker:
		confirm_checkpoint((target as CheckpointMarker).marker_id)


# -- Camps (GDD rule 13a, States CampPrompt; story 113) ----------------------

## The CampSpot the open prompt belongs to, or null.
func get_camp_prompt_camp() -> CampSpot:
	return _camp_prompt_camp if _camp_prompt_open else null


func _open_camp_prompt(camp: CampSpot) -> void:
	_camp_prompt_camp = camp
	camp_prompt_focus = CampChoice.YES
	_camp_prompt_open = true


func _close_camp_prompt() -> void:
	_camp_prompt_open = false
	_camp_prompt_camp = null


## Input while the prompt is open; every action is consumed. `cancel` acts
## as No: it closes the prompt with no camp request. A move toggles the
## focus. `confirm` takes the focused choice: Yes requests the Camp mode
## (or, while `config.camp_mode_enabled` is off, registers the camp and
## closes).
func _handle_camp_prompt(action: StringName, pressed: bool) -> bool:
	if not pressed:
		return true
	match action:
		InputActions.CANCEL:
			_close_camp_prompt()
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT, InputActions.MOVE_UP, InputActions.MOVE_DOWN:
			camp_prompt_focus = CampChoice.NO if camp_prompt_focus == CampChoice.YES else CampChoice.YES
		InputActions.CONFIRM:
			var camp: CampSpot = _camp_prompt_camp
			var choice: CampChoice = camp_prompt_focus
			_close_camp_prompt()
			if choice == CampChoice.YES and camp != null:
				_rest_at(camp)
	return true


func _rest_at(camp: CampSpot) -> void:
	if _machine == null:
		return
	if not config.camp_mode_enabled:
		_machine.register_camp(camp.camp_id)
		return
	var payload := CampEntryPayload.new()
	payload.camp_id = camp.camp_id
	camp_requests += 1
	_machine.request_transition(GameStateMachine.Mode.CAMP, payload)


## Rule 13a "Passing a CampSpot registers it": entering a CampSpot's safe
## zone (within `safe_radius_m`) asks Game State to register it, once per
## entry.
func _check_camp_registration() -> void:
	if _map == null or _machine == null:
		return
	var inside: CampSpot = null
	for camp: CampSpot in _map.camp_spots():
		if _leader_pos.distance_to(camp.ground_position(_map)) <= config.safe_radius_m:
			inside = camp
			break
	if inside != null and inside != _camp_zone:
		_machine.register_camp(inside.camp_id)
	_camp_zone = inside


# -- Lines, barks and first sight (stories 071, 091) -------------------------

## Opens `text` as a Dialogue line (the interim line overlay until the
## Dialogue system exists). `then` runs on the same frame as the line's
## `overlay_closed` (ADR-0012 §6). Returns Game State's result; on a
## rejection `then` is dropped.
func say(text: String, then: Callable = Callable()) -> GameStateMachine.RequestResult:
	if _machine == null:
		return GameStateMachine.RequestResult.REJECTED_INVALID_PAYLOAD
	var result: GameStateMachine.RequestResult = _machine.open_overlay(
			GameStateMachine.OverlayKind.DIALOGUE, DialogueLinePayload.new(text))
	if result == GameStateMachine.RequestResult.OK:
		_after_line = then
		lines_said.append(text)
	return result


## The checkpoint's authored failure line, or a plain default that names the
## missing requirement (rule 10).
func _failure_line(cp: CheckpointMarker) -> String:
	if not cp.failure_line.is_empty():
		return cp.failure_line
	var missing: String = cp.requirement_flag if not cp.requirement_flag.is_empty() else cp.requirement_item_id
	if cp.failure_outcome == CheckpointMarker.FailureOutcome.QUEUE:
		return "Please take a number and wait to be called. (%s)" % missing
	return "No %s? Back of the queue." % missing


## Rule 13a, each frame in Exploring. A `confirm`-started Static symbol
## barks its `bark_line` the first time the leader touches it, once ever;
## and the first frame it is on screen (within the camera's visibility edge
## in its direction) sets its first-sight flag, which activates its camp
## decree (`is_first_seen()`).
func _check_barks_and_sight() -> void:
	var reach: float = 2.0 * config.body_radius
	for source: EncounterSource in _sources:
		if not source.brain.is_static() or source.brain.contact_eligible():
			continue
		var offset: Vector2 = source.brain.position - _leader_pos
		if not source.bark_line.is_empty() and offset.length() <= reach \
				and not _has_flag("barked:" + source.symbol_id):
			_set_flag("barked:" + source.symbol_id)
			barked.emit(source.bark_line, source.brain.position)
		if not _has_flag("seen:" + source.symbol_id) and offset.length() \
				<= ChaseVisibility.edge_reach(offset, presentation, config.walk_speed):
			_set_flag("seen:" + source.symbol_id)


## `true` once `symbol_id` has been on screen (rule 13a first sight; its
## camp decree is active from then on). TODO(overworld): the decree gag
## marker itself (stories 016/122).
func is_first_seen(symbol_id: String) -> bool:
	return _has_flag("seen:" + symbol_id)


func _has_flag(flag: String) -> bool:
	return world_state.has_flag(flag) if world_state != null else _flags_this_visit.has(flag)


func _set_flag(flag: String) -> void:
	if world_state != null:
		world_state.set_flag(flag)
	else:
		_flags_this_visit[flag] = true


## What the interact prompt shows over `probe()`'s target (GDD UI
## Requirements kind icons): `&"rest"` for a CampSpot, `&"ticket"` for a
## `confirm`-started Static symbol (the story encounter), `&"fight"` for
## the boss, `&"check"` for a checkpoint, `&""` for nothing in reach.
func probe_kind() -> StringName:
	var target: Object = probe()
	if target is CampSpot:
		return &"rest"
	if target is EncounterSource:
		return &"fight" if (target as EncounterSource).brain.contact_eligible() else &"ticket"
	if target is CheckpointMarker:
		return &"check"
	return &""
