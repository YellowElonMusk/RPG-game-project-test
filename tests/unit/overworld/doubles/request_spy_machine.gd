## Test double: a `GameStateMachine` whose `request_transition()` records
## every call and returns scripted results (FIFO; `OK` once empty).
class_name RequestSpyMachine
extends GameStateMachine

## Every payload passed, in call order.
var payloads: Array[RefCounted] = []
## Every target passed, in call order.
var targets: Array[int] = []
## Results to return, FIFO.
var scripted: Array[int] = []


func _init() -> void:
	super(null, null, null, null, Callable(), null)


func request_transition(target: Mode, payload: RefCounted = null) -> RequestResult:
	targets.append(target)
	payloads.append(payload)
	if scripted.is_empty():
		return RequestResult.OK
	return scripted.pop_front() as RequestResult


## The encounter IDs of every recorded payload, in call order.
func encounter_ids() -> Array[String]:
	var ids: Array[String] = []
	for p: RefCounted in payloads:
		ids.append((p as BattleEntryPayload).descriptor.encounter_id)
	return ids
