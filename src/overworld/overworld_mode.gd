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
## `presentation_settings` yet either (both are TODOs in
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


func _init() -> void:
	# Pinned ordering (ADR-0012 §2): GameRoot -20, OverworldMode -10,
	# FollowCamera 0, CharacterSprite +10. process_priority sorts globally,
	# regardless of tree order (probed, 4.7.2).
	process_priority = -10


func setup(machine: GameStateMachine, _payload: RefCounted) -> void:
	_machine = machine


## No discrete action is handled yet (routing lands in story 010+); always
## falls through so a later `handle_action` override is additive, not a
## rewrite.
func handle_action(_action: StringName, _pressed: bool) -> bool:
	return false


## Reads movement only through `machine.get_move_vector(self)` (control
## manifest; ADR-0012 §2) and steps on `ow_dt = min(delta, dt_max)`.
func _process(delta: float) -> void:
	if _machine == null:
		return
	var ow_dt: float = minf(delta, _DT_MAX_FALLBACK)
	var input_vec: Vector2 = _machine.get_move_vector(self)
	var result: GroundMover.MoveResult = GroundMover.step(
			_leader_pos, input_vec, ow_dt, null, config, config.walk_speed, 0)
	_leader_pos = result.position
