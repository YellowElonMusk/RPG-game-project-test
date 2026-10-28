## Records `GameStateMachine._init`'s `quit_hook` calls into the shared
## `SequenceRecorder` (when given one).
class_name QuitSpy extends RefCounted

var call_count: int = 0

var _recorder: SequenceRecorder


func _init(recorder: SequenceRecorder = null) -> void:
	_recorder = recorder


func quit() -> void:
	call_count += 1
	if _recorder != null:
		_recorder.record(&"quit", [])


## The `Callable` to pass as `_init`'s `quit_hook` argument.
func as_callable() -> Callable:
	return Callable(self, "quit")
