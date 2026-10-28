## Scriptable flash-gate double satisfying `FlashGatePort` (ADR-0005 §12,
## story 017). Records every `request()` call so a test can assert the
## machine booked exactly once, with the expected `(source_id, clock,
## priority)`. `capped_result` scripts the outcome: `false` grants (returns
## a positive handle), `true` refuses (`-1`).
class_name StubFlashGate extends FlashGatePort

var requests: Array[Dictionary] = []
var capped_result: bool = false


func request(source_id: StringName, clock: float, priority: float) -> int:
	requests.append({"source_id": source_id, "clock": clock, "priority": priority})
	return -1 if capped_result else 1
