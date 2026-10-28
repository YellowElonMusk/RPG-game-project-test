## Project config `Resource` for transition timings and scene path tables
## (ADR-0002 §9). Fields only — no logic, per ADR-0001's data rules — and not
## a catalog record type: `GameRoot._ready()` loads it directly with
## `ResourceLoader.load()`, because the Boot -> Title fade needs it before any
## catalog-dependent code runs. `GameStateMachine` reads these dictionaries
## directly; it never calls a method on this Resource.
class_name TransitionConfig extends Resource

## Transition type (StringName, e.g. `&"battle_wipe"`) -> OUT duration (seconds).
@export var t_out: Dictionary = {}
## Transition type -> IN duration (seconds).
@export var t_in: Dictionary = {}
## Transition type -> total swap budget (seconds). Enforcement — logging a
## performance warning when `t_swap` runs past budget — is a later story.
@export var transition_budget: Dictionary = {}
## `GameStateMachine.Mode` (int) -> mode scene path. `String` only, never a
## `PackedScene` export, per ADR-0001's data-only rules.
@export var mode_scene_paths: Dictionary = {}
## `GameStateMachine.OverlayKind` (int) -> overlay scene path. `String` only.
@export var overlay_scene_paths: Dictionary = {}
## Interim flag (ADR-0002 §8): false until ADR-0001's enemy-record migration
## lands. Load-time validation against it is story 006.
@export var validate_enemy_ids_against_catalog: bool = false


## Load-time check (ADR-0002 §9, story 006): a transition's `transition_budget`
## must cover its measured `t_out + t_in` (SWAP is bounded separately, by the
## loader finishing — see ADR-0002 §3). Logs one `budget_below_phases` error
## per offending row (`context.type` is the row's `StringName`) and does not
## stop at the first bad row. The comparison is strict: `budget == t_out + t_in`
## is not an error. Rows of type `&"none"` are skipped — the GDD Budgets table
## has no row for `none` (Boot -> Content Error, exit). Returns `false` if any
## row failed.
func validate(log_sink: GameStateLog) -> bool:
	var ok: bool = true
	for transition_type: StringName in t_out.keys():
		if transition_type == &"none":
			continue
		var out_time: float = float(t_out.get(transition_type, 0.0))
		var in_time: float = float(t_in.get(transition_type, 0.0))
		var budget: float = float(transition_budget.get(transition_type, 0.0))
		if budget < out_time + in_time:
			log_sink.error(&"budget_below_phases", {"type": transition_type})
			ok = false
	return ok
