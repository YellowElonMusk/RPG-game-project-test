## Scriptable flash-gate double. Not yet consulted by `GameStateMachine`
## (flash-gate booking lands in story 017); provided now so that story's
## tests don't need a new double. Duck-typed `Object`, not a `FlashGate`
## class — none exists yet.
class_name StubFlashGate extends RefCounted

var capped_result: bool = false


func request(_source_id: StringName, _real_clock: float, _priority: float) -> bool:
	return not capped_result
