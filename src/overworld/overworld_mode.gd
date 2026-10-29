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

var _machine: GameStateMachine = null

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
## the point left open -- only the leader has a position in logic). Empty
## until story 006's trail-spacing formula starts calling
## `set_follower_positions()` every frame; story 005 (this story) proves the
## array's isolation, not its contents -- `_process()` never reads it.
## Positions only, no `CharacterSprite`s (those are story 007's scope,
## ADR-0012 §4 step 5); this is the seam stories 006-010 extend.
var _follower_positions: Array[Vector2] = []


func _init() -> void:
	# Pinned ordering (ADR-0012 §2): GameRoot -20, OverworldMode -10,
	# FollowCamera 0, CharacterSprite +10. process_priority sorts globally,
	# regardless of tree order (probed, 4.7.2).
	process_priority = -10


func setup(machine: GameStateMachine, _payload: RefCounted) -> void:
	_machine = machine


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
	var input_vec: Vector2 = _machine.get_move_vector(self)
	var result: GroundMover.MoveResult = GroundMover.step(
			_leader_pos, input_vec, ow_dt, null, config, config.walk_speed, 0)
	_leader_pos = result.position
	_last_distance_moved = result.distance_moved


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
## (empty until story 006 calls it). Returns a duplicate so the caller can
## never mutate this mode's own copy through the returned array.
## `_process()` itself never calls this (story 005, AC-3) -- only rendering
## (story 007+) is meant to.
func get_follower_positions() -> Array[Vector2]:
	return _follower_positions.duplicate()
