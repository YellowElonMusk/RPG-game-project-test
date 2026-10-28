## Records `GameStateMachine._init`'s `mark_unsaved` hook calls (ADR-0002
## §11, story 020) -- stands in for a future `SaveService.mark_unsaved()`
## (ADR-0009) until SaveService exists.
class_name UnsavedProgressSpy extends RefCounted

var call_count: int = 0

var _recorder: SequenceRecorder


func _init(recorder: SequenceRecorder = null) -> void:
	_recorder = recorder


func mark_unsaved() -> void:
	call_count += 1
	if _recorder != null:
		_recorder.record(&"mark_unsaved", [])


## The `Callable` to pass as `_init`'s `mark_unsaved` argument.
func as_callable() -> Callable:
	return Callable(self, "mark_unsaved")
