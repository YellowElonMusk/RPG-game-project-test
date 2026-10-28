## Connects to all six `GameStateMachine` signals and is also handed to the
## quit spy, the stub loader, the stub presenter and the stub modes, so every
## before/after assertion in this epic can compare indices in one shared,
## ordered array. gdUnit4's signal monitor counts signal emissions but does
## not order them against each other or against plain method calls.
class_name SequenceRecorder extends RefCounted

var events: Array[Dictionary] = []


func attach(machine: GameStateMachine) -> void:
	machine.transition_started.connect(
			func(from: GameStateMachine.Mode, to: GameStateMachine.Mode) -> void:
				record(&"transition_started", [from, to]))
	machine.mode_exited.connect(
			func(from: GameStateMachine.Mode) -> void:
				record(&"mode_exited", [from]))
	machine.mode_entered.connect(
			func(to: GameStateMachine.Mode) -> void:
				record(&"mode_entered", [to]))
	machine.transition_finished.connect(
			func(to: GameStateMachine.Mode) -> void:
				record(&"transition_finished", [to]))
	machine.overlay_opened.connect(
			func(kind: GameStateMachine.OverlayKind) -> void:
				record(&"overlay_opened", [kind]))
	machine.overlay_closed.connect(
			func(kind: GameStateMachine.OverlayKind) -> void:
				record(&"overlay_closed", [kind]))


## Appends `{event, args}`. Called directly by doubles that are not signals
## (the stub loader, presenter, quit spy and modes) so their calls land in
## the same ordered array.
func record(event: StringName, args: Array) -> void:
	events.append({"event": event, "args": args})


func clear() -> void:
	events.clear()


## Index of the first event named `event`, from `start`, or -1.
func index_of(event: StringName, start: int = 0) -> int:
	for i in range(start, events.size()):
		if events[i]["event"] == event:
			return i
	return -1
