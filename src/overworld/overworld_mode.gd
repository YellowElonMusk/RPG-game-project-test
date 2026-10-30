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
## `probe()` calls so far (story 013 asserts none run while locked out).
var probe_calls: int = 0
## Codex rumours added by clue gags (story 016).
var rumours_added: int = 0
## Set while the map name card is on screen (story 111 owns the card); a
## teaching bark due meanwhile waits until it is cleared (story 123).
var name_card_showing: bool = false
## optional_teach NpcSpawn -> true while armed (story 123).
var _teach_armed: Dictionary = {}
## optional_teach NpcSpawns whose bark is due but waiting on the name card.
var _teach_pending: Dictionary = {}
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
## Story 068: `true` while the open prompt is the chapter-end one ("End the
## chapter here?", verb and `accessibility_name` "End chapter"; No focused).
var camp_prompt_is_chapter_end: bool = false
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
## Set by `setup()` for Title's Continue (a `LoadedSave` payload): `_ready()`
## loads `world_state.map_id` at the saved position (ADR-0009 §6).
var _continuing: bool = false


func _init() -> void:
	# Pinned ordering (ADR-0012 §2): GameRoot -20, OverworldMode -10,
	# FollowCamera 0, CharacterSprite +10. process_priority sorts globally,
	# regardless of tree order (probed, 4.7.2).
	process_priority = -10


func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	if payload is MapEntryPayload:
		_entry_payload = payload as MapEntryPayload
	_continuing = payload is LoadedSave
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
	if _continuing and world_state != null and not world_state.map_id.is_empty():
		_continue_from_save()
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
	for gag: GagInteractable in map.gags():
		if _has_flag(_gag_flag("changed", gag)):
			map.set_gag_shown(gag.marker_id, false)
	_queue_name_card()
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
		# Story 068: a flag-closed exit is taped off and never fires.
		if not exit.closed_when_flag.is_empty() and _has_flag(exit.closed_when_flag):
			if exit.closed_rect.size != Vector2.ZERO:
				_grid.set_blocked(_rect_cells(exit.closed_rect), true)
			map.set_exit_taped(exit.marker_id, true)
			continue
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
	_advance_step_on_entry()
	_compute_stage()
	_resolve_presentation()
	_activate_markers()
	_setup_clutter(_map)
	_refresh_gags()
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
	# Rule 9: in a liberated region every symbol is inactive, beaten or not.
	if is_region_liberated():
		return
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
	if _walk_home_pending:
		_try_walk_home()
	if _machine == null:
		return
	var ow_dt: float = minf(delta, _DT_MAX_FALLBACK)
	step_frame(ow_dt, _machine.get_move_vector(self))
	tick_timed_text(delta)


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
	_check_teach_barks()
	if _budget == null:
		_budget = QueryBudget.new(config.repath_per_frame_max)
	_budget.begin_frame()
	var symbol_from: Array[Vector2] = []
	for source: EncounterSource in _sources:
		symbol_from.append(source.brain.position)
		if _grid != null:
			source.brain.step(ow_dt, _leader_pos, _grid, grace_active, config, _budget)
	_check_contact(leader_from, symbol_from)
	_mirror_world_state()


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
	_mirror_world_state()
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
				# Rule 18 registry: the Victory also sets the checkpoint's
				# requirement flag (`counter_cleared`, the Permit Counter).
				var cp: CheckpointMarker = _checkpoints.get(source.checkpoint_id) as CheckpointMarker
				if cp != null and not cp.requirement_flag.is_empty():
					_set_flag(cp.requirement_flag)
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
	_grant_payoff(source, rec)
	_liberate_for(source.symbol_id)
	_liberate_region_if_boss(rec)
	_queue_walk_home(rec)


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
	# Story 111: a map load's reveal shows its name card (never a thaw or a
	# redirect: those load no map).
	if _name_card_due:
		_show_name_card()
	# Story 050: a Victory's payoffs show on this reveal.
	_show_payoff_card()
	# Story 060: on-screen liberations play their removal from the reveal.
	_start_removals()
	# Rule 13a: after Fled from the story encounter, its line opens as an
	# automatic Dialogue on the reveal, guarded against a held confirm.
	if not _line_on_reveal.is_empty():
		var line: String = _line_on_reveal
		_line_on_reveal = ""
		say(line)
	# Story 068: the boss's post-battle Dialogue, then the walk home.
	_open_post_battle_dialogue()


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


## Rule 10: exactly one requirement, an item or a story flag, read from
## `world_state` (items are the interim `item:<id>` flags `item` payoffs
## grant, story 050, until an inventory exists).
func _requirement_met(cp: CheckpointMarker) -> bool:
	if not cp.requirement_flag.is_empty():
		return _has_flag(cp.requirement_flag)
	if not cp.requirement_item_id.is_empty():
		return _has_flag("item:" + cp.requirement_item_id)
	return false


func _map_id() -> String:
	return _map.map_id if _map != null else ""


# -- Interaction (GDD rule 3) -----------------------------------------------

## The nearest eligible target within `interact_reach_m` of the probe point
## (`facing * body_radius` ahead of the leader), or null (GDD rule 3,
## stories 011 and 016). Targets and eligibility:
## - NPCs and CampSpots: always;
## - Static symbols: while unresolved;
## - checkpoints: while closed, except a story encounter's own while its
##   Static symbol stands;
## - gags: `line` and `clue` always (they repeat), `change` until changed.
## On an exact tie the order is NPC, CampSpot, Static symbol, then
## Interactable (checkpoint or gag): candidates are visited in that order and
## only a strictly nearer one replaces the best. Returns an `NpcSpawn`,
## `CampSpot`, `EncounterSource`, `CheckpointMarker` or `GagInteractable`.
## TODO(overworld): liberated markers drop out too, once liberation exists
## (rule 9, stories 059-060).
func probe() -> Object:
	probe_calls += 1
	var point: Vector2 = _leader_pos + _leader_facing.normalized() * config.body_radius
	var candidates: Array = []  # [target, ground position], in tie order
	if _map != null:
		for npc: NpcSpawn in _map.npc_spawns():
			if is_npc_active(npc):
				candidates.append([npc, npc.ground_position(_map)])
		for camp: CampSpot in _map.camp_spots():
			candidates.append([camp, camp.ground_position(_map)])
	var guarded: Dictionary = {}
	for source: EncounterSource in _sources:
		if not source.brain.is_static():
			continue
		if source.checkpoint_id != &"":
			guarded[source.checkpoint_id] = true
		candidates.append([source, source.brain.position])
	for marker_id: StringName in _checkpoints:
		if not is_checkpoint_open(marker_id) and not guarded.has(marker_id):
			var cp: CheckpointMarker = _checkpoints[marker_id]
			candidates.append([cp, cp.ground_position(_map)])
	if _map != null:
		for gag: GagInteractable in _map.gags():
			if not is_gag_active(gag):
				continue
			if gag.response != GagInteractable.Response.CHANGE or not _has_flag(_gag_flag("changed", gag)):
				candidates.append([gag, gag.ground_position(_map)])
	var best: Object = null
	var best_d: float = INF
	var reach: float = config.interact_reach_m + 1e-6
	for c: Array in candidates:
		var d: float = point.distance_to(c[1])
		if d <= reach and d < best_d:
			best = c[0]
			best_d = d
	return best


## `confirm` in Exploring acts on `probe()`'s result (GDD rule 3). Nothing
## in reach does nothing (story 012: no line, no sound).
func confirm() -> void:
	var target: Object = probe()
	if target is NpcSpawn:
		var npc: NpcSpawn = target
		say(npc.line, Callable(), npc.speaker)
	elif target is CampSpot:
		_open_camp_prompt(target as CampSpot)
	elif target is EncounterSource:
		var source: EncounterSource = target
		start_encounter(source.enc_id, source)
	elif target is CheckpointMarker:
		confirm_checkpoint((target as CheckpointMarker).marker_id)
	elif target is GagInteractable:
		confirm_gag(target as GagInteractable)


## `confirm` at a gag (GDD rule 16; story 016). `LINE` repeats, its
## `alt_text` from the second time on; `CHANGE` shows its line once and
## drops out of `probe()` for good; `CLUE` repeats its line and adds its
## rumour only the first time.
func confirm_gag(gag: GagInteractable) -> void:
	if gag.is_decree():
		say(gag.text)  # a decree repeats its text, always (rule 3)
		return
	var used: bool = _has_flag(_gag_flag("used", gag))
	_set_flag(_gag_flag("used", gag))
	match gag.response:
		GagInteractable.Response.LINE:
			say(gag.alt_text if used and not gag.alt_text.is_empty() else gag.text)
		GagInteractable.Response.CHANGE:
			if _has_flag(_gag_flag("changed", gag)):
				return
			_set_flag(_gag_flag("changed", gag))
			if _map != null:
				_map.set_gag_shown(gag.marker_id, false)
			say(gag.text)
		GagInteractable.Response.CLUE:
			if not gag.rumour_id.is_empty() and not _has_flag("rumour:" + gag.rumour_id):
				_set_flag("rumour:" + gag.rumour_id)
				rumours_added += 1
			say(gag.text)


## `true` once rumour `rumour_id` is in the Codex (GDD rule 7a clue).
## TODO(codex): the Combo System & Codex owns the rumour list itself.
func has_rumour(rumour_id: String) -> bool:
	return _has_flag("rumour:" + rumour_id)


func _gag_flag(kind: String, gag: GagInteractable) -> String:
	return "gag_%s:%s:%s" % [kind, _map_id(), gag.marker_id]



# -- Camps (GDD rule 13a, States CampPrompt; story 113) ----------------------

## The CampSpot the open prompt belongs to, or null.
func get_camp_prompt_camp() -> CampSpot:
	return _camp_prompt_camp if _camp_prompt_open else null


func _open_camp_prompt(camp: CampSpot) -> void:
	_camp_prompt_camp = camp
	# Story 068 (rule 13): the region default camp on the final step asks
	# to end the chapter instead, with No focused (it cannot be undone).
	camp_prompt_is_chapter_end = camp.is_region_default and is_on_final_step()
	camp_prompt_focus = CampChoice.NO if camp_prompt_is_chapter_end else CampChoice.YES
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
			var ending: bool = camp_prompt_is_chapter_end
			_close_camp_prompt()
			if ending:
				if choice == CampChoice.YES:
					_end_chapter()
			elif choice == CampChoice.YES and camp != null:
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
func say(text: String, then: Callable = Callable(), speaker: String = "") -> GameStateMachine.RequestResult:
	if _machine == null:
		return GameStateMachine.RequestResult.REJECTED_INVALID_PAYLOAD
	var result: GameStateMachine.RequestResult = _machine.open_overlay(
			GameStateMachine.OverlayKind.DIALOGUE, DialogueLinePayload.new(text, speaker))
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
			_bark(source.bark_line, source.brain.position)
		if not _has_flag("seen:" + source.symbol_id) and offset.length() \
				<= ChaseVisibility.edge_reach(offset, presentation, config.walk_speed):
			_set_flag("seen:" + source.symbol_id)
			_refresh_gags()


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
	return kind_of(probe())


## The prompt kind of a `probe()` result (see `probe_kind()`).
static func kind_of(target: Object) -> StringName:
	if target is NpcSpawn:
		return &"talk"
	if target is CampSpot:
		return &"rest"
	if target is EncounterSource:
		return &"fight" if (target as EncounterSource).brain.contact_eligible() else &"ticket"
	if target is CheckpointMarker:
		return &"check"
	if target is GagInteractable:
		return &"look"
	return &""


## The ground position of a `probe()` result, where the prompt is drawn
## (story 015).
func target_position(target: Object) -> Vector2:
	if target is EncounterSource:
		return (target as EncounterSource).brain.position
	if target is Node3D and _map != null:
		return OverworldMap.ground_position_of(target as Node3D, _map)
	return _leader_pos


## Story 123 (GDD rule 16 "Clerks are optional"): each frame in Exploring,
## an `optional_teach` speaker barks its line when the leader comes within
## `interact_reach_m * 2` of it, with no input and without stopping the
## leader. It re-arms only once the leader is beyond twice that distance. A
## bark due while the name card shows waits until the card is gone.
func _check_teach_barks() -> void:
	if _map == null:
		return
	var near: float = config.interact_reach_m * 2.0
	for npc: NpcSpawn in _map.npc_spawns():
		if not npc.optional_teach or not is_npc_active(npc):
			continue
		var at: Vector2 = npc.ground_position(_map)
		var d: float = _leader_pos.distance_to(at)
		var armed: bool = _teach_armed.get(npc, true)
		if armed and d <= near:
			_teach_armed[npc] = false
			_teach_pending[npc] = true
		elif not armed and d > near * 2.0:
			_teach_armed[npc] = true
		if _teach_pending.has(npc) and not name_card_showing:
			_teach_pending.erase(npc)
			_bark(npc.line, at)


## Title's Continue (ADR-0009 §6, ADR-0012 §4): the committed `WorldState`
## names the map; the party lands on `continue_entry` when the save was
## made in Camp, else on the saved position and facing. Continue respawns
## nothing (`EntryKind.CONTINUE`: `map_id` already matches).
func _continue_from_save() -> void:
	var path: String = OverworldMap.scene_path(world_state.map_id, config.map_scene_dir)
	var scene: PackedScene = ResourceLoader.load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_error("OverworldMode: no map scene at %s for Continue" % path)
		return
	var entry: StringName = StringName(world_state.continue_entry)
	var pos: Vector2 = world_state.party_pos
	var facing: Vector2 = world_state.party_facing
	load_map(scene.instantiate() as OverworldMap, entry)
	if entry == &"":
		_leader_pos = pos
		if not facing.is_zero_approx():
			_leader_facing = facing.normalized()
		_reform_followers()
	world_state.continue_entry = ""


## ADR-0012 §4: `WorldState` holds the party's position and facing, written
## every frame, so a save is always current.
func _mirror_world_state() -> void:
	if world_state != null and _map != null:
		world_state.party_pos = _leader_pos
		world_state.party_facing = _leader_facing


# -- Timed text: the map name card (story 111, GDD UI Requirements) --------

## Stage words the name card must never show (GDD: "It never shows the
## stage word").
const STAGE_WORDS: Array[String] = ["Contested", "Occupied", "Saturated"]

## Phases of a timed text element.
enum CardPhase { HIDDEN, SHOWN, FADING }

## The card's text while it is up, "" otherwise.
var name_card_text: String = ""
var name_card_phase: CardPhase = CardPhase.HIDDEN
var _name_card_elapsed: float = 0.0
var _name_card_due: bool = false
var _after_name_card: Array[String] = []


## Called by `load_map()`: the card shows on this load's reveal (or at once
## when the load runs outside a transition: tests, the demo scene). A thaw
## or a redirect never loads a map, so it never shows one.
func _queue_name_card() -> void:
	if _machine != null and _machine.phase != GameStateMachine.Phase.IDLE:
		_name_card_due = true
	else:
		_show_name_card()


func _show_name_card() -> void:
	_name_card_due = false
	name_card_text = map_display_name()
	name_card_phase = CardPhase.SHOWN
	_name_card_elapsed = 0.0
	name_card_showing = true


## The current map's player-facing name from its `map_` record, never a
## stage word; the map ID when no record is reachable.
func map_display_name() -> String:
	var name: String = _map_id()
	if encounter_catalog != null and _map != null:
		var rec: Resource = encounter_catalog.call(&"get_record", &"map", _map.map_id)
		if rec != null and not String(rec.get("display_name")).is_empty():
			name = String(rec.get("display_name"))
	for word: String in STAGE_WORDS:
		name = name.replace(word, "").strip_edges()
	return name


## Advances every timed text by `dt`, paused while any overlay is open (GDD
## "Timed text"). Called once a frame by `_process()`; tests call it.
func tick_timed_text(dt: float) -> void:
	if _overlays_open > 0:
		return
	if name_card_phase != CardPhase.HIDDEN:
		_name_card_elapsed += dt
		var hold: float = config.text_hold(name_card_text)
		if _name_card_elapsed > hold + config.text_fade_s:
			name_card_phase = CardPhase.HIDDEN
			name_card_text = ""
			name_card_showing = false
			_release_after_name_card()
		elif _name_card_elapsed > hold:
			name_card_phase = CardPhase.FADING
	_tick_payoff_card(dt)
	_tick_removals(dt)
	_tick_bark(dt)


## A story Dialogue due on a map load opens after the name card has faded
## (GDD UI Requirements); at once when no card is up.
func say_after_name_card(text: String) -> void:
	if name_card_showing or _name_card_due:
		_after_name_card.append(text)
	else:
		say(text)


func _release_after_name_card() -> void:
	if _after_name_card.is_empty():
		return
	var text: String = _after_name_card.pop_front()
	say(text)


# -- Timed text: the bark window (story 130) --------------------------------

## The bark on screen, "" when none.
var bark_text: String = ""
var bark_phase: CardPhase = CardPhase.HIDDEN
var _bark_elapsed: float = 0.0


func _start_bark(text: String) -> void:
	bark_text = text
	bark_phase = CardPhase.SHOWN
	_bark_elapsed = 0.0


func _tick_bark(dt: float) -> void:
	if bark_phase == CardPhase.HIDDEN:
		return
	_bark_elapsed += dt
	var hold: float = config.text_hold(bark_text)
	if _bark_elapsed > hold + config.text_fade_s:
		bark_phase = CardPhase.HIDDEN
		bark_text = ""
	elif _bark_elapsed > hold:
		bark_phase = CardPhase.FADING


## Shows a bark in the bark window (held for `text_hold`) and announces it.
func _bark(text: String, at: Vector2) -> void:
	_start_bark(text)
	barked.emit(text, at)


# -- Victory payoffs and the payoff card (stories 050 and 130) -------------

## The payoff card's text while it is up (one line per result), "" otherwise.
var payoff_card_text: String = ""
var payoff_card_phase: CardPhase = CardPhase.HIDDEN
var _payoff_card_elapsed: float = 0.0
var _payoff_lines: Array[String] = []
var _after_payoff_card: Array[String] = []
## Items granted by `item` payoffs (tests read it).
var items_added: int = 0


## GDD rule 7a: the first Victory over a symbol grants its record's
## `victory_payoff`; a respawned Clerk (its symbol already paid out) grants
## nothing. `clue` adds a rumour and queues its interim stub line behind the
## payoff card; `open` opens the linked checkpoint; `item` adds the item.
## Each result adds one payoff-card line, shown on the reveal.
func _grant_payoff(source: EncounterSource, rec: EncounterData) -> void:
	if rec == null or rec.victory_payoff.is_empty():
		return
	var granted: String = "payoff:%s:%s" % [_map_id(), source.symbol_id]
	if _has_flag(granted):
		return
	_set_flag(granted)
	var p: Dictionary = rec.victory_payoff
	match String(p.get("type", "none")):
		"clue":
			var facet: String = String(p.get("facet", ""))
			if not facet.is_empty() and not _has_flag("rumour:" + facet):
				_set_flag("rumour:" + facet)
				rumours_added += 1
			_payoff_lines.append("Rumour noted in the Codex")
			var stub: String = String(p.get("text", ""))
			if not stub.is_empty():
				_after_payoff_card.append(stub)
		"open":
			var cp_id := StringName(String(p.get("checkpoint", "")))
			if _checkpoints.has(cp_id):
				open_checkpoint(cp_id)
				_payoff_lines.append("Shortcut opened: %s" % String(p.get("label", cp_id)))
			else:
				push_error("OverworldMode: payoff opens unknown checkpoint '%s'" % cp_id)
		"item":
			var item_id: String = String(p.get("item_id", ""))
			if not item_id.is_empty():
				_set_flag("item:" + item_id)
				items_added += 1
				_payoff_lines.append("Got: %s" % String(p.get("label", item_id)))


## On the reveal after a Victory: shows the payoff card for the granted
## results, if any (called from `_on_transition_finished`).
func _show_payoff_card() -> void:
	# A queued stub line follows only the card fading, never a later reveal.
	if _payoff_lines.is_empty():
		return
	payoff_card_text = "\n".join(_payoff_lines)
	_payoff_lines.clear()
	payoff_card_phase = CardPhase.SHOWN
	_payoff_card_elapsed = 0.0


## The card holds for `text_hold` summed over its lines (GDD UI
## Requirements), then fades; ticked by `tick_timed_text`, so it pauses
## under overlays.
func _tick_payoff_card(dt: float) -> void:
	if payoff_card_phase == CardPhase.HIDDEN:
		return
	_payoff_card_elapsed += dt
	var hold: float = payoff_card_hold()
	if _payoff_card_elapsed > hold + config.text_fade_s:
		payoff_card_phase = CardPhase.HIDDEN
		payoff_card_text = ""
		_release_after_payoff_card()
	elif _payoff_card_elapsed > hold:
		payoff_card_phase = CardPhase.FADING


## `text_hold` summed over the payoff card's lines.
func payoff_card_hold() -> float:
	var hold: float = 0.0
	for line: String in payoff_card_text.split("\n", false):
		hold += config.text_hold(line)
	return hold


## A `clue` payoff's interim stub line opens only after the card has faded.
func _release_after_payoff_card() -> void:
	if _after_payoff_card.is_empty():
		return
	# A Dialogue from the same battle also waits for on-screen removals.
	if not _removals.is_empty() or not _removals_due.is_empty():
		return
	say(_after_payoff_card.pop_front())


# -- Occupation stage (stories 053, 054) -------------------------------------

## The current map's occupation stage (1 Contested .. 3 Saturated), 0 when
## its record has none to compute. Computed on map load only (rule 8: a flag
## set mid-visit waits for the next load) and never below the stored stage.
var current_stage: int = 0
## Warnings from stage computation (a raising flag removed), for tests.
var stage_warnings: Array[String] = []


func _compute_stage() -> void:
	current_stage = 0
	if encounter_catalog == null or _map == null:
		return
	var rec: MapData = encounter_catalog.call(&"get_record", &"map", _map.map_id) as MapData
	if rec == null:
		return
	var stored: int = world_state.stage_stored(_map.map_id) if world_state != null else 0
	var result: Array = OccupationStage.compute(rec, _has_flag, stored)
	current_stage = result[0]
	if not String(result[1]).is_empty():
		stage_warnings.append(result[1])
		push_warning(result[1])
	if world_state != null:
		world_state.store_stage(_map.map_id, current_stage)


# -- Presentation override (story 066) ----------------------------------------

## The map's resolved presentation for this visit (rule 17), set on the
## map-entry commit, before the reveal. The stage itself is never changed.
var presentation_profile_id: StringName = &""
var set_kit_id: String = ""
var civilian_density: float = 0.0
var ambience_bed_id: String = ""


## Rule 17: from the current stage's `occupation_stage` record, or, once the
## region is liberated, the map's `liberated_profile_id` / `liberated_kit_id`
## with stage 1's civilian density and ambience bed. A stage record with no
## lighting profile, or a map with none, falls back to `overworld`. The kit
## is applied to the map here; the profile is handed to its `DioramaStage`
## when it has one (ADR-0005 §4 applies it before the reveal).
func _resolve_presentation() -> void:
	presentation_profile_id = &"overworld"
	set_kit_id = ""
	civilian_density = 0.0
	ambience_bed_id = ""
	if _map == null:
		return
	var map_rec: MapData = null
	if encounter_catalog != null:
		map_rec = encounter_catalog.call(&"get_record", &"map", _map.map_id) as MapData
	if map_rec != null:
		var liberated: bool = is_region_liberated()
		var o: OccupationStageData = _ostage(map_rec.faction_id, 1 if liberated else current_stage)
		if o != null:
			civilian_density = o.civilian_density
			ambience_bed_id = o.ambience_bed_id
		if liberated:
			if not map_rec.liberated_profile_id.is_empty():
				presentation_profile_id = StringName(map_rec.liberated_profile_id)
			set_kit_id = map_rec.liberated_kit_id
		elif o != null and current_stage > 0:
			if not o.lighting_profile_id.is_empty():
				presentation_profile_id = StringName(o.lighting_profile_id)
			set_kit_id = o.set_kit_id
	_map.apply_set_kit(SetKit.resolve(set_kit_id))
	for stage: Node in _map.find_children("*", "DioramaStage", true, false):
		(stage as DioramaStage).profile_id = presentation_profile_id
	for npc: NpcSpawn in _map.npc_spawns():
		_map.set_npc_shown(npc.marker_id, is_npc_active(npc))


## `true` while `npc` is present: ordinary NPCs always, liberated-set ones
## (story 066) only once the region is liberated.
func is_npc_active(npc: NpcSpawn) -> bool:
	return npc.liberated_role.is_empty() or is_region_liberated()


## The `occupation_stage` record for `faction_id` x `stage`, or null.
func _ostage(faction_id: String, stage: int) -> OccupationStageData:
	if encounter_catalog == null or not encounter_catalog.has_method(&"all_records") or stage <= 0:
		return null
	for r: Resource in encounter_catalog.call(&"all_records", &"occupation_stage"):
		var o: OccupationStageData = r as OccupationStageData
		if o != null and o.faction_id == faction_id and o.stage == stage:
			return o
	return null


# -- Marker activation (story 058) --------------------------------------------

## Capped clutter markers holding a slot this visit (`marker_id -> true`).
var _slotted: Dictionary = {}


## Rule 8 / `marker_activation`, once per map load after the stage: every
## clutter-kind gag (decrees excepted, rule 8) competes for its kind's cap
## from the faction x stage `occupation_stage` record, sorted by
## (`min_stage`, marker order). A map with no stage (no record) slots every
## marker; a kind its record does not cap is uncapped.
func _activate_markers() -> void:
	_slotted.clear()
	if _map == null:
		return
	var markers: Array = []
	var order: int = 0
	for gag: GagInteractable in _map.gags():
		order += 1
		if gag.clutter_kind.is_empty() or gag.is_decree():
			continue
		markers.append({"id": gag.marker_id, "kind": gag.clutter_kind,
				"min_stage": gag.min_stage, "order": order})
	if current_stage <= 0:
		for m: Dictionary in markers:
			_slotted[m["id"]] = true
		return
	_slotted = MarkerActivation.slotted(markers, current_stage, _stage_caps())


## The current map's faction x stage clutter caps, `{}` when no
## `occupation_stage` record matches.
func _stage_caps() -> Dictionary:
	if encounter_catalog == null:
		return {}
	var map_rec: MapData = encounter_catalog.call(&"get_record", &"map", _map.map_id) as MapData
	var o: OccupationStageData = _ostage(map_rec.faction_id, current_stage) if map_rec != null else null
	return o.clutter_caps if o != null else {}


# -- Decree gags (story 056) --------------------------------------------------

## `true` while `gag` is active: an ordinary gag always (until clutter
## liberation, stories 059-060); a decree at and above its stage, or once
## its symbol has been seen; never once the map's region is liberated.
func is_gag_active(gag: GagInteractable) -> bool:
	# Story 066: liberated-set content shows only once the region is.
	if not gag.liberated_role.is_empty():
		return is_region_liberated()
	var clears: bool = gag.is_liberatable() or gag.is_decree() or not gag.clutter_kind.is_empty()
	if clears and _gag_liberated(gag) and not is_removing(gag):
		return false
	# Story 058: a capped clutter marker shows only while it holds a slot.
	if not gag.clutter_kind.is_empty() and not gag.is_decree() and not _slotted.has(gag.marker_id):
		return false
	if not gag.is_decree():
		return true
	if is_region_liberated():
		return false
	if gag.decree_stage > 0 and current_stage < gag.decree_stage:
		return false
	if not gag.decree_first_sight.is_empty() and not is_first_seen(gag.decree_first_sight):
		return false
	return true


## `true` once the current map's `region_liberation_flag` is set (rule 9:
## evaluated on every load and check, never stored per marker).
func is_region_liberated() -> bool:
	if encounter_catalog == null or _map == null:
		return false
	var rec: MapData = encounter_catalog.call(&"get_record", &"map", _map.map_id) as MapData
	return rec != null and not rec.region_liberation_flag.is_empty() and _has_flag(rec.region_liberation_flag)


## Shows only the active gags' placeholder boards (and hides a `change` gag
## already changed).
func _refresh_gags() -> void:
	if _map == null:
		return
	for gag: GagInteractable in _map.gags():
		var changed: bool = gag.response == GagInteractable.Response.CHANGE and _has_flag(_gag_flag("changed", gag))
		_map.set_gag_shown(gag.marker_id, is_gag_active(gag) and not changed)


# -- Local and region liberation (stories 059, 060; GDD rule 9) -------------

## On-screen removals playing after the reveal: [GagInteractable, elapsed].
var _removals: Array = []
## Liberations from the last Victory waiting for the reveal (on-screen).
var _removals_due: Array[GagInteractable] = []


## Blocks every unliberated queue's cells and hides liberated boards; called
## on map load (region liberation is evaluated on every load, rule 9).
func _setup_clutter(map: OverworldMap) -> void:
	for gag: GagInteractable in map.gags():
		var freed: bool = _gag_liberated(gag) or not is_gag_active(gag)
		if gag.blocked_rect.size != Vector2.ZERO and _grid != null:
			_grid.set_blocked(_rect_cells(gag.blocked_rect), not freed)


## `true` once `gag` is liberated: its own Victory or flag, or the region.
func _gag_liberated(gag: GagInteractable) -> bool:
	if not gag.is_liberatable() and not gag.is_decree() and gag.clutter_kind.is_empty():
		return false
	if is_region_liberated():
		return true
	if world_state != null and world_state.is_liberated(_map_id(), gag.marker_id):
		return true
	return not gag.liberation_flag.is_empty() and _has_flag(gag.liberation_flag)


## Rule 9 timing, on a Victory over `symbol_id` (from `on_thawed`): every
## clutter marker it liberates joins the map's liberated set now. One the
## camera does not show is removed at once (cells freed) and named on the
## payoff card; one on screen waits for the reveal, then plays its removal
## over `liberation_duration_s` on the mode clock. A respawned Clerk's
## markers are already liberated, so beating it again adds nothing.
func _liberate_for(symbol_id: String) -> void:
	if _map == null:
		return
	for gag: GagInteractable in _map.gags():
		if gag.liberate_symbol != symbol_id or _gag_liberated(gag):
			continue
		if world_state != null:
			world_state.liberate(_map_id(), gag.marker_id)
		if _on_screen(gag.ground_position(_map)):
			_removals_due.append(gag)
		else:
			_finish_removal(gag)
			_payoff_lines.append("Street cleared: %s" % (gag.street_label if not gag.street_label.is_empty() else String(gag.marker_id)))


## Whether ground point `p` is on screen from the leader (the camera's
## guaranteed visibility edge in its direction).
func _on_screen(p: Vector2) -> bool:
	var offset: Vector2 = p - _leader_pos
	return offset.length() <= ChaseVisibility.edge_reach(offset, presentation, config.walk_speed)


## Starts the on-screen removals at the reveal (`transition_finished`).
func _start_removals() -> void:
	for gag: GagInteractable in _removals_due:
		_removals.append([gag, 0.0])
	_removals_due.clear()


## Advances on-screen removals; each completes after `liberation_duration_s`
## (board hidden, cells freed). Paused under overlays with all timed text.
func _tick_removals(dt: float) -> void:
	for r: Array in _removals:
		r[1] = float(r[1]) + dt
	var still: Array = []
	for r: Array in _removals:
		if float(r[1]) >= config.liberation_duration_s:
			_finish_removal(r[0])
		else:
			still.append(r)
	_removals = still
	if _removals.is_empty() and payoff_card_phase == CardPhase.HIDDEN:
		_release_after_payoff_card()


func _finish_removal(gag: GagInteractable) -> void:
	if _map != null:
		_map.set_gag_shown(gag.marker_id, false)
	if gag.blocked_rect.size != Vector2.ZERO and _grid != null:
		_grid.set_blocked(_rect_cells(gag.blocked_rect), false)


## `true` while an on-screen removal is due or playing (tests).
func is_removing(gag: GagInteractable) -> bool:
	for r: Array in _removals:
		if r[0] == gag:
			return true
	return _removals_due.has(gag)


func _rect_cells(r: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lo := Vector2i(floori(r.position.x / _grid.cell_m), floori(r.position.y / _grid.cell_m))
	var hi := Vector2i(ceili(r.end.x / _grid.cell_m) - 1, ceili(r.end.y / _grid.cell_m) - 1)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			out.append(Vector2i(x, y))
	return out


## Rule 13: a boss Victory sets the region's `region_liberation_flag`.
func _liberate_region_if_boss(rec: EncounterData) -> void:
	if rec == null or not rec.is_boss or encounter_catalog == null or _map == null:
		return
	var map_rec: MapData = encounter_catalog.call(&"get_record", &"map", _map.map_id) as MapData
	if map_rec != null and not map_rec.region_liberation_flag.is_empty():
		_set_flag(map_rec.region_liberation_flag)


# -- The walk home (story 068; GDD rule 13) ----------------------------------

## Emitted once, from Yes in the chapter-end prompt on the final step.
## TODO(dialogue-quests): what ending a chapter does (credits, the next
## region) is not designed; GameRoot does not listen yet.
signal chapter_end_requested
## Chapter-end calls (tests spy on it).
var chapter_end_calls: int = 0
## Set by a boss Victory (when the chapter has a last act): the post-battle
## Dialogue opens on the reveal, and the walk home follows its close.
var _walk_home_due: bool = false
var _walk_home_line: String = ""
## The walk home's map change is owed (the request was busy or blocked);
## retried every frame until Game State accepts it.
var _walk_home_pending: bool = false
var _chapter: ChapterSteps = null


## The chapter's step list (from `config.chapter_steps_path`), or null.
func chapter_steps() -> ChapterSteps:
	if _chapter == null and config != null and ResourceLoader.exists(config.chapter_steps_path):
		_chapter = ResourceLoader.load(config.chapter_steps_path) as ChapterSteps
	return _chapter


## Injects a step list (tests).
func set_chapter_steps(steps: ChapterSteps) -> void:
	_chapter = steps


## The index of `world_state.chapter_step`, or -1.
func _step_index() -> int:
	var steps: ChapterSteps = chapter_steps()
	if steps == null or world_state == null:
		return -1
	for i: int in steps.steps.size():
		if steps.steps[i].id == world_state.chapter_step:
			return i
	return -1


## `true` on the chapter's final step (B): the café asks to end the chapter.
func is_on_final_step() -> bool:
	var steps: ChapterSteps = chapter_steps()
	var i: int = _step_index()
	return steps != null and i >= 0 and i == steps.steps.size() - 1


## Rule 13: a boss Victory that liberates the region, in a chapter with a
## last act, queues the walk home.
func _queue_walk_home(rec: EncounterData) -> void:
	var steps: ChapterSteps = chapter_steps()
	if rec == null or not rec.is_boss or steps == null or steps.last_act_from.is_empty():
		return
	# Only a Victory that liberated the region (its map names a
	# `region_liberation_flag`) ends the chapter's middle.
	if not is_region_liberated():
		return
	_walk_home_due = true
	_walk_home_line = rec.post_battle_line


## On the reveal after the boss Victory: the post-battle story Dialogue, then
## the walk home on its close (whichever input closed it). No line, or a
## line Game State will not open, goes straight to the walk home.
func _open_post_battle_dialogue() -> void:
	if not _walk_home_due:
		return
	_walk_home_due = false
	if _walk_home_line.is_empty() \
			or say(_walk_home_line, _start_walk_home) != GameStateMachine.RequestResult.OK:
		_start_walk_home()


## Rule 13: step A begins and a map change takes the squad to the first
## last-act step's map at `last_act_entry_id` (the segment's dungeon side),
## which loads liberated (story 066) with its dungeon exit taped.
func _start_walk_home() -> void:
	var steps: ChapterSteps = chapter_steps()
	if steps == null:
		return
	if world_state != null:
		world_state.chapter_step = steps.last_act_from
	_walk_home_pending = true
	_try_walk_home()


func _try_walk_home() -> void:
	if not _walk_home_pending or _machine == null:
		return
	var step: ChapterStep = _step_by_id(chapter_steps().last_act_from)
	if step == null:
		_walk_home_pending = false
		return
	var result: GameStateMachine.RequestResult = _machine.request_transition(
			GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new(step.map_id, chapter_steps().last_act_entry_id))
	if result == GameStateMachine.RequestResult.OK:
		_walk_home_pending = false


## `true` while the walk home's map change is still owed (tests).
func is_walk_home_pending() -> bool:
	return _walk_home_pending or _walk_home_due


func _step_by_id(id: String) -> ChapterStep:
	var steps: ChapterSteps = chapter_steps()
	if steps == null:
		return null
	for step: ChapterStep in steps.steps:
		if step.id == id:
			return step
	return null


## Rule 13: in the last act, entering the next step's map advances to it
## (A -> B on entering Town). Called on the map-entry commit.
func _advance_step_on_entry() -> void:
	var steps: ChapterSteps = chapter_steps()
	var i: int = _step_index()
	if steps == null or world_state == null or i < 0 or i + 1 >= steps.steps.size() or _map == null:
		return
	var act_start: int = steps.steps.find(_step_by_id(steps.last_act_from))
	if act_start < 0 or i < act_start:
		return
	if steps.steps[i + 1].map_id == _map.map_id:
		world_state.chapter_step = steps.steps[i + 1].id


## Yes in the chapter-end prompt: the only caller (spied by tests).
func _end_chapter() -> void:
	chapter_end_calls += 1
	chapter_end_requested.emit()
