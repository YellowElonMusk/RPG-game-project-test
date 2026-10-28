## Story 025, verification item 3 (ADR-0002 Engine Compatibility, "still
## open"): confirms an `AnimationPlayer` playing a 1s track freezes while its
## `ModeHost` ancestor is `PROCESS_MODE_DISABLED` and resumes once
## re-enabled -- the same `process_mode` mechanism already verified for
## `Timer` and node-bound `Tween`. Loader-level: drives the real
## `ModeHostSceneLoader.set_mode_time_stopped()` against a real `ModeHost`
## `Node` with real children, never `GameStateMachine`. Written to the QA
## Test Cases in
## `production/epics/game-state-scene-flow/story-025-menu-stops-time-quit-to-title.md`
## -- no new cases invented.
extends GdUnitTestSuite


func test_animation_player_and_timer_freeze_while_disabled() -> void:
	# Arrange: a real ModeHost Node with a Timer and an AnimationPlayer child
	# playing a 1s animation, wrapped by a real ModeHostSceneLoader.
	var mode_host := Node.new()
	add_child(mode_host)
	auto_free(mode_host)

	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	var game_log := SpyGameStateLog.new()
	var loader := ModeHostSceneLoader.new(mode_host, cfg, game_log)

	var timer := Timer.new()
	timer.wait_time = 10.0
	timer.one_shot = false
	mode_host.add_child(timer)
	auto_free(timer)
	timer.start()

	var player := AnimationPlayer.new()
	mode_host.add_child(player)
	auto_free(player)
	var anim := Animation.new()
	anim.length = 1.0
	var library := AnimationLibrary.new()
	library.add_animation(&"track", anim)
	player.add_animation_library(&"", library)
	player.play(&"track")

	await get_tree().process_frame

	var timer_before: float = timer.time_left
	var anim_position_before: float = player.current_animation_position

	# Act: disable ModeHost for 10 frames.
	loader.set_mode_time_stopped(true)
	assert_int(mode_host.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	for i in range(10):
		await get_tree().process_frame

	# Assert: both the Timer and the AnimationPlayer stayed put while disabled.
	assert_float(timer.time_left).is_equal_approx(timer_before, 1e-6)
	assert_float(player.current_animation_position).is_equal_approx(anim_position_before, 1e-6)

	# Act: re-enable ModeHost for 10 more frames.
	loader.set_mode_time_stopped(false)
	assert_int(mode_host.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	for i in range(10):
		await get_tree().process_frame

	# Assert: both resumed after re-enabling.
	assert_float(timer.time_left).is_less(timer_before)
	assert_float(player.current_animation_position).is_greater(anim_position_before)


## Edge case (code-review item, QA Test Cases): neither `SceneTree.paused`
## nor `Engine.time_scale` is referenced anywhere in `src/game_state/`.
func test_no_scene_tree_paused_or_time_scale_reference() -> void:
	var dir := DirAccess.open("res://src/game_state/")
	assert_object(dir).is_not_null()
	var files: PackedStringArray = _gather_gd_files("res://src/game_state/")
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		assert_bool(text.contains("SceneTree.paused")).override_failure_message(
				"%s references SceneTree.paused" % path).is_false()
		assert_bool(text.contains("Engine.time_scale")).override_failure_message(
				"%s references Engine.time_scale" % path).is_false()


## Recursively lists every `.gd` file under `dir_path`.
func _gather_gd_files(dir_path: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full_path: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				result.append_array(_gather_gd_files(full_path))
			elif entry.ends_with(".gd"):
				result.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return result
