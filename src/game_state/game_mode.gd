## Base class for every mode scene's root script (ADR-0002 Key Interfaces).
## `@abstract`: on 4.7.2 `GameMode.new()` is a parser error, so every test
## double subclasses this base.
@abstract class_name GameMode extends Node

## Called by `SceneLoader` before `add_child()`, with the machine and the
## request's payload (`null` for modes entered without one).
func setup(_machine: GameStateMachine, _payload: RefCounted) -> void:
	pass


## Returns `true` if this mode consumed the action; `false` lets it fall
## through. Routing to this call is story-010's concern.
@abstract func handle_action(action: StringName, pressed: bool) -> bool


## Asked by `SceneLoader` right after this mode's node is added during SWAP.
## `true` means it could not build itself (an Overworld whose map scene is
## missing), and the loader rolls the swap back (ADR-0012 §2,
## `OVERWORLD -> OVERWORLD`). The base never fails.
func swap_failed() -> bool:
	return false


## Overworld only. Runs before `SceneLoader` detaches this mode's node.
func on_freezing() -> void:
	pass


## Overworld only. Runs after `mode_entered(OVERWORLD)`, once the detached
## instance has been re-attached.
func on_thawed(_encounter_id: String, _result: GameStateMachine.BattleResult) -> void:
	pass


## Battle only. The base returns `null`, which the machine treats as a swap
## failure, so a Battle mode that forgets to override this fails loudly
## instead of silently losing Retry.
func capture_start_snapshot() -> RefCounted:
	return null


## Battle only.
func restore_start_snapshot(_snapshot: RefCounted) -> void:
	pass
