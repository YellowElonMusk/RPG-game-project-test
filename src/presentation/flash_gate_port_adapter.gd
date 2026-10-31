## Lets `GameStateMachine` book its transition flashes through the real
## `FlashGate` (ADR-0005 §12; story 017's `FlashGatePort`). The machine
## passes its real-time clock *reading* and a rate; the gate wants the clock
## itself, so the reading is wrapped as a constant clock. That is exact for
## the machine's use: its flashes run at rate 1 on real time and it never
## re-books (`set_rate`), the one call that reads the clock again.
##
## Usage example:
## [codeblock]
## var port := FlashGatePortAdapter.new(flash_gate)
## var machine := GameStateMachine.new(loader, presenter, config, catalog, quit, log, port)
## [/codeblock]
class_name FlashGatePortAdapter
extends FlashGatePort

var _gate: FlashGate


func _init(gate: FlashGate) -> void:
	_gate = gate


## `FlashGate.request()` with `clock` as a constant reading and `priority`
## as the source's rate. Returns the handle, or `FlashGate.REFUSED` (-1).
func request(source_id: StringName, clock: float, priority: float) -> int:
	if _gate == null:
		return FlashGate.REFUSED
	return _gate.request(source_id, func() -> float: return clock, priority)
