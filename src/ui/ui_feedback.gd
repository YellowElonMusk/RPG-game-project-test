## Refusal feedback (ADR-0008 §7; story 058): `refuse(control)` is called once
## per refused press. This records it and emits `refused`; the visible pulse
## and the soft tick are presented by the UI service listening to `refused`
## (story 074's evidence). `control` may be null (tick only).
class_name UiFeedback
extends RefCounted

## Emitted once per `refuse()` call, with the focused control or null.
signal refused(control: Control)

## Refusals so far (diagnostics and tests).
var refusal_count: int = 0


## Signals one refusal on `control` (null = no focused control).
func refuse(control: Control) -> void:
	refusal_count += 1
	refused.emit(control)
