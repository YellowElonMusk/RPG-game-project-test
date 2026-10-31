## Applies a mode's lighting profile before the transition reveals it
## (ADR-0005 Decision §4, Key Interfaces `presentation_director.gd`). A
## service under `GameRoot/Services` (not wired there yet -- see the
## `setup()` follow-up).
##
## On `mode_entered(to)`, which fires at the end of SWAP, before the reveal
## (`GameStateMachine._end_swap_phase_success()` / `_end_retry_swap()`), this
## takes the group's single `DioramaStage`, if any, hands it a profile
## resolver (`stage.bind_profiles()`), and applies `profiles[stage.profile_id]`
## at `blend_time = 0`, hidden behind the wipe.
##
## Same-mode rows skip the apply. `from`/`to` are learned from
## `transition_started(from, to)`: on a same-mode row (Battle -> Battle for
## Retry, ADR-0002 §7) this still rebinds, but does not apply the entry
## profile, because the owning mode has already set the Retry light during
## the hidden SWAP -- applying `battle` at blend 0 here would overwrite it.
##
## "One door" (ADR-0005 §3): this class calls only `stage.bind_profiles()` and
## `stage.apply_profile()` -- never `stage.request_profile()`, which is the
## owning mode's call only.
##
## Profile resolution reads `data/presentation/profiles/<id>.tres` directly by
## convention (matching `tests/unit/presentation/lighting_profile_test.gd`'s
## own discovery). `PresentationConfig`'s full profile table (ADR-0005 §5) is
## a later story's scope -- `setup()` already takes the config to match the
## ADR's interface shape, but this story's logic never reads it.
##
## TODO(sprite-camera-presentation): `overlay_opened`/`overlay_closed(MENU)`
## ambient pause and the every-frame `mode_time`/`actor_rim_color`/
## `actor_rim_strength` writes through `GlobalUniformSink` are story 010's
## scope (menu-freeze-stops-every-presentation-clock), not this story's.
class_name PresentationDirector extends Node

const _PROFILES_DIR: String = "res://data/presentation/profiles"
## `blend_time` for this class's own entry-profile apply (ADR-0005 §4):
## always instant, hidden behind the wipe. The owning mode's own blended
## `request_profile()` calls (story 009/026) are never this.
const _ENTRY_BLEND_TIME: float = 0.0

var _machine: GameStateMachine
var _config: PresentationConfig
var _sink: GlobalUniformSink
var _pending_from: GameStateMachine.Mode = GameStateMachine.Mode.BOOT
var _pending_to: GameStateMachine.Mode = GameStateMachine.Mode.BOOT


## Injected once by `GameRoot` (ADR-0005 §4). `config` and `sink` are stored
## for story 009/010's use; this story's logic reads neither.
## TODO(scene-flow): wire a `PresentationDirector` instance into `GameRoot`'s
## service set and call this -- out of scope here, the scene-flow epic's own
## story.
func setup(machine: GameStateMachine, config: PresentationConfig, sink: GlobalUniformSink) -> void:
	_machine = machine
	_config = config
	_sink = sink
	_machine.transition_started.connect(_on_transition_started)
	_machine.mode_entered.connect(_on_mode_entered)


func _on_transition_started(from: GameStateMachine.Mode, to: GameStateMachine.Mode) -> void:
	_pending_from = from
	_pending_to = to


## Fires at the end of SWAP, before the reveal (see class doc). Looks up the
## single live `DioramaStage` through its group every time, never a stored
## reference -- the stage that answers changes with every mode swap.
func _on_mode_entered(_to: GameStateMachine.Mode) -> void:
	var stage: DioramaStage = _find_stage()
	if stage == null:
		return
	stage.bind_profiles(_resolve_profile)
	if _pending_from == _pending_to:
		return  # same-mode row (Retry): the owning mode already set the light
	var profile: LightingProfile = _resolve_profile(stage.profile_id)
	if profile == null:
		push_error("PresentationDirector: unknown entry lighting profile '%s'" % stage.profile_id)
		return
	stage.apply_profile(profile, _ENTRY_BLEND_TIME)


## The group's single stage (ADR-0005 §3). `null` with no member (a 2D mode)
## -- expected, so nothing is logged; `null` with more than one member too,
## but logged, since that is never a valid scene.
func _find_stage() -> DioramaStage:
	var stages: Array[Node] = get_tree().get_nodes_in_group(DioramaStage.GROUP)
	if stages.is_empty():
		return null
	if stages.size() > 1:
		push_error("PresentationDirector: more than one active_diorama_stage node; applying none")
		return null
	return stages[0] as DioramaStage


## `resolver.call(id) -> LightingProfile` (ADR-0005 §3's `bind_profiles()`
## contract): `null` for an unknown id, with nothing logged here -- the caller
## that asked logs it once (the stage's `request_profile()`, story 032).
func _resolve_profile(id: StringName) -> LightingProfile:
	return resolve_profile(id)


## The profile `id` from table directory `dir`, or null (no engine error,
## no log) when it does not exist.
func resolve_profile(id: StringName, dir: String = _PROFILES_DIR) -> LightingProfile:
	var path: String = dir.path_join("%s.tres" % id)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as LightingProfile
