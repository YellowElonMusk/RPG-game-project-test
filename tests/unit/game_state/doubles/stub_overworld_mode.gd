## Subclasses `GameMode` (every test double must: `GameMode.new()` on the
## abstract base is a parser error on 4.7.2). Scene fixture
## `stub_overworld_mode.tscn` (story 014) attaches this script and adds a
## child `Timer`, so this double carries the GDD rule-5 snapshot fields
## (party position and facing, current map, NPC/enemy states, story flags)
## plus lifecycle counters that prove freeze is detach-only: `_ready()` runs
## once in total, `_enter_tree()`/`_exit_tree()` once per move (ADR-0002 §4,
## verified empirically on 4.7.2).
class_name StubOverworldMode extends GameMode

## GDD rule-5 snapshot fields. Defaults are this fixture's known values —
## the test's "fixture" is simply `snapshot_fields()` read once, before the
## round trip.
var party_position: Vector2 = Vector2(128.0, 64.0)
var party_facing: Vector2 = Vector2.DOWN
var map_id: String = "map_fixture_01"
var npc_states: Dictionary = {"npc_01": "idle", "npc_02": "hostile"}
var enemy_states: Dictionary = {"enemy_01": "patrolling"}
var story_flags: Dictionary = {"flag_intro_seen": true, "flag_boss_defeated": false}

var freeze_count: int = 0
var thaw_calls: Array[Dictionary] = []

## Story 010: counts `handle_action` calls, so a test can prove nothing (or
## exactly one thing) reached this mode.
var handle_action_count: int = 0
var last_action: StringName = &""
var last_pressed: bool = false

## A copy of `snapshot_fields()` taken inside `on_thawed()`, before anything
## `on_thawed()` might do could mutate a field — so the test always compares
## against this, not against the live fields read later.
var thaw_snapshot: Dictionary = {}

var ready_count: int = 0
var enter_tree_count: int = 0
var exit_tree_count: int = 0

var _tween: Tween = null
var _tween_progress: float = 0.0

@onready var _timer: Timer = $Timer

var _recorder: SequenceRecorder


func set_recorder(recorder: SequenceRecorder) -> void:
	_recorder = recorder


func handle_action(action: StringName, pressed: bool) -> bool:
	handle_action_count += 1
	last_action = action
	last_pressed = pressed
	return false


func on_freezing() -> void:
	freeze_count += 1
	if _recorder != null:
		_recorder.record(&"on_freezing", [])


func on_thawed(encounter_id: String, result: GameStateMachine.BattleResult) -> void:
	thaw_calls.append({"encounter_id": encounter_id, "result": result})
	thaw_snapshot = snapshot_fields()
	if _recorder != null:
		_recorder.record(&"on_thawed", [encounter_id, result])


## Every GDD rule-5 field, as a fresh `Dictionary` (nested dictionaries
## duplicated so the caller never reads through to this node's live state).
func snapshot_fields() -> Dictionary:
	return {
		"party_position": party_position,
		"party_facing": party_facing,
		"map_id": map_id,
		"npc_states": npc_states.duplicate(true),
		"enemy_states": enemy_states.duplicate(true),
		"story_flags": story_flags.duplicate(true),
	}


## `Timer.time_left` (ADR-0002 Engine Notes: safe to assert on; `-1.0` if
## the child `Timer` is missing).
func get_timer_time_left() -> float:
	return _timer.time_left if _timer != null else -1.0


## `Tween.get_total_elapsed_time()` (ADR-0002 Engine Notes: `Tween.is_running()`
## stays `true` while frozen, so elapsed time is the only safe assertion;
## `-1.0` if no Tween has been created yet).
func get_tween_elapsed() -> float:
	return _tween.get_total_elapsed_time() if _tween != null else -1.0


func _ready() -> void:
	ready_count += 1
	_tween = create_tween()
	_tween.tween_property(self, "_tween_progress", 100.0, 1000.0)


func _enter_tree() -> void:
	enter_tree_count += 1


func _exit_tree() -> void:
	exit_tree_count += 1
