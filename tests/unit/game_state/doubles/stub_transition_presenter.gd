## Scriptable `TransitionPresenter` double. Records every `play_out()` /
## `play_in()` call into the shared `SequenceRecorder` (when given one) so
## tests can assert ordering against the machine's own signals, and never
## requests a completion callback (the contract is fire-and-forget).
class_name StubTransitionPresenter extends TransitionPresenter

var play_out_calls: Array[Dictionary] = []
var play_in_calls: Array[Dictionary] = []

var _recorder: SequenceRecorder


func _init(recorder: SequenceRecorder = null) -> void:
	_recorder = recorder


func play_out(transition_type: StringName, duration: float, capped: bool = false) -> void:
	play_out_calls.append({"type": transition_type, "duration": duration, "capped": capped})
	if _recorder != null:
		_recorder.record(&"play_out", [transition_type, duration, capped])


func play_in(transition_type: StringName, duration: float, capped: bool = false) -> void:
	play_in_calls.append({"type": transition_type, "duration": duration, "capped": capped})
	if _recorder != null:
		_recorder.record(&"play_in", [transition_type, duration, capped])
