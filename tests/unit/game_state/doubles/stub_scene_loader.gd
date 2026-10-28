## Scriptable `SceneLoader` double. `poll_swap()` returns whatever was pushed
## via `script_results()`, FIFO; once the queue is empty it defaults to
## `DONE`, so an unscripted swap (e.g. the Boot/Title fast-forward in
## `game_state_fixtures.gd`) completes on its very next poll.
class_name StubSceneLoader extends SceneLoader

var begin_swap_count: int = 0
var last_begin_swap_args: Array = []
var rollback_count: int = 0
var push_overlay_count: int = 0
var pop_overlay_count: int = 0
var last_push_overlay_payload: RefCounted = null
var current_mode_node_value: Node = null
var current_overlay_node_value: Node = null

var _recorder: SequenceRecorder
var _queue: Array[SwapStatus] = []


func _init(recorder: SequenceRecorder = null) -> void:
	_recorder = recorder


## Appends to the poll queue; does not replace what is already scripted.
func script_results(results: Array[SwapStatus]) -> void:
	_queue.append_array(results)


func begin_swap(from: int, to: int, payload: RefCounted) -> void:
	begin_swap_count += 1
	last_begin_swap_args = [from, to, payload]
	if _recorder != null:
		_recorder.record(&"begin_swap", [from, to])


func poll_swap() -> SwapStatus:
	if _queue.is_empty():
		return SwapStatus.DONE
	return _queue.pop_front()


func rollback_swap() -> void:
	rollback_count += 1
	if _recorder != null:
		_recorder.record(&"rollback_swap", [])


func push_overlay(kind: int, payload: RefCounted) -> void:
	push_overlay_count += 1
	last_push_overlay_payload = payload
	if _recorder != null:
		_recorder.record(&"push_overlay", [kind])


func pop_overlay() -> void:
	pop_overlay_count += 1
	if _recorder != null:
		_recorder.record(&"pop_overlay", [])


func current_mode_node() -> Node:
	return current_mode_node_value


func current_overlay_node() -> Node:
	return current_overlay_node_value
