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
