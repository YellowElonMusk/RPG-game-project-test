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
enum State { EXPLORING, FROZEN }

## GDD Formulas swept contact: below this `|b|^2` the bodies did not move
## relative to each other (a formula constant, not a tuning knob).
const _ZERO_REL_DISPLACEMENT_SQ: float = 1e-8

## Duck-typed record source with `get_record(type, id) -> Resource` (the
## `ContentCatalogService` in the game; injected, never the autoload).
var encounter_catalog: Object = null
## Returns the party (`Array[Combatant]`) for the battle payload.
## TODO(overworld): ChapterFlow's interim party / Squad Roster (ADR-0012 §5).
var party_source: Callable = Callable()
## Encounter grace (GDD rule 7). TODO(overworld): story 047 drives it.
var grace_active: bool = false
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
var _budget: QueryBudget = null

var _machine: GameStateMachine = null

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
## caller. TODO(ow-epic): `reset()` this on map entry, teleport, redirect
## and thaw once that wiring exists (story 007).
var _follower_trail: FollowerTrail = FollowerTrail.new()


func _init() -> void:
	# Pinned ordering (ADR-0012 §2): GameRoot -20, OverworldMode -10,
	# FollowCamera 0, CharacterSprite +10. process_priority sorts globally,
	# regardless of tree order (probed, 4.7.2).
	process_priority = -10


func setup(machine: GameStateMachine, _payload: RefCounted) -> void:
	_machine = machine
	if machine != null and not machine.transition_finished.is_connected(_on_transition_finished):
		machine.transition_finished.connect(_on_transition_finished)


func _ready() -> void:
	if map_scene != null and _map == null:
		load_map(map_scene.instantiate() as OverworldMap)


## Loads `map` (story 136; ADR-0012 §2): parents it under `map_parent` if it
## has no parent yet, bakes its `WalkGrid` once, builds the set geometry,
## places the leader on the map's spawn cell and re-anchors the follower
## trail there.
func load_map(map: OverworldMap) -> void:
	if map == null:
		push_error("OverworldMode: load_map() given a null or non-OverworldMap scene")
		return
	_map = map
	if map.get_parent() == null:
		(map_parent if map_parent != null else self).add_child(map)
	_grid = map.bake_walk_grid(config)
	map.build_set(_grid)
	_leader_pos = map.spawn_position(_grid)
	_follower_trail.reset(_leader_pos)


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
func handle_action(_action: StringName, _pressed: bool) -> bool:
	return false


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
	if _state != State.EXPLORING:
		return
	var leader_from: Vector2 = _leader_pos
	var result: GroundMover.MoveResult = GroundMover.step(
			_leader_pos, input_vec, ow_dt, _grid, config, config.walk_speed, 0, true)
	_leader_pos = result.position
	_last_distance_moved = result.distance_moved
	if _check_exits(leader_from, _leader_pos):
		return
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
func add_symbol(enc_id: String, brain: SymbolBrain) -> EncounterSource:
	var source := EncounterSource.new(enc_id, brain)
	var at: int = _sources.size()
	for i in _sources.size():
		if _sources[i].brain.marker_index > brain.marker_index:
			at = i
			break
	_sources.insert(at, source)
	return source


## Registers a `MapExit` rectangle in ground metres. Crossing into it (enter
## edge only) requests the exit via `map_exit_requested`.
func add_map_exit(exit_id: StringName, rect: Rect2) -> void:
	_exit_ids.append(exit_id)
	_exit_rects.append(rect)


## Injects a baked walk grid without a map scene (tests, ADR-0012 §2).
func set_walk_grid(grid: WalkGrid) -> void:
	_grid = grid


## Places the leader (map entry, tests). Re-anchors the follower trail.
func set_leader_position(pos: Vector2) -> void:
	_leader_pos = pos
	_follower_trail.reset(pos)


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
			# TODO(overworld): MapChanging + the map-change request (map stories).
			map_exit_requested.emit(_exit_ids[i])
			return true
	return false


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


## ADR-0012 §5 `transition_finished`: back to Exploring after the thaw; grace
## starts and Noticing/Chasing symbols switch to Returning (GDD rule 7).
## TODO(overworld): the grace timer itself (story 047) and `on_thawed`.
func _on_transition_finished(to: GameStateMachine.Mode) -> void:
	if to != GameStateMachine.Mode.OVERWORLD:
		return
	_state = State.EXPLORING
	pending_source = null
	for source: EncounterSource in _sources:
		source.brain.on_grace_started()


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
