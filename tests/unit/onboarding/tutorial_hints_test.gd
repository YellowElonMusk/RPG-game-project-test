## Onboarding & Tutorial (systems index #21): one-time hints are shown once,
## saved in WorldState, silenced (not consumed) by the Settings toggle, and
## the controls strip drops each part once done.
extends GdUnitTestSuite

var _on: Array = [true]


func before_test() -> void:
	_on[0] = true


func _hints(world: WorldState) -> TutorialHints:
	var on: Array = _on
	return TutorialHints.new(world, func() -> bool: return on[0])


func test_hint_is_due_until_marked_seen_then_never_again() -> void:
	var hints := _hints(WorldState.new())
	assert_bool(hints.is_due(TutorialHints.FIRST_BATTLE)).is_true()
	hints.mark_seen(TutorialHints.FIRST_BATTLE)
	assert_bool(hints.is_due(TutorialHints.FIRST_BATTLE)).is_false()
	assert_bool(hints.is_due(TutorialHints.CAMP)).is_true()


func test_seen_hints_survive_a_save_round_trip() -> void:
	var world := WorldState.new()
	_hints(world).mark_seen(TutorialHints.rule_id("faction_megacorp"))
	var loaded := WorldState.new()
	# `from_dict` takes the save participant's staged section; the flags
	# pass through it unchanged.
	loaded.from_dict({"flags": world.to_dict()["flags"]})
	var hints := _hints(loaded)
	assert_bool(hints.is_due(TutorialHints.rule_id("faction_megacorp"))).is_false()
	assert_bool(hints.is_due(TutorialHints.rule_id("faction_bureaucratia"))).is_true()


func test_new_game_resets_seen_hints() -> void:
	var world := WorldState.new()
	var hints := _hints(world)
	hints.mark_seen(TutorialHints.MOVE)
	world.reset_to_new_game()
	assert_bool(hints.is_due(TutorialHints.MOVE)).is_true()


func test_toggle_off_shows_nothing_and_marks_nothing() -> void:
	var hints := _hints(WorldState.new())
	_on[0] = false
	assert_bool(hints.is_due(TutorialHints.FIRST_BATTLE)).is_false()
	hints.mark_seen(TutorialHints.FIRST_BATTLE)
	_on[0] = true
	assert_bool(hints.is_due(TutorialHints.FIRST_BATTLE)).override_failure_message(
			"a hint skipped while off must still show once switched back on").is_true()


func test_no_toggle_callable_means_on() -> void:
	assert_bool(TutorialHints.new(WorldState.new()).enabled()).is_true()


func test_controls_strip_drops_each_part_once_done() -> void:
	var hints := _hints(WorldState.new())
	var glyphs := PromptGlyphs.new(load(BattleMode.BINDINGS_PATH) as InputBindings)
	assert_str(hints.controls_text(glyphs)).is_equal("[WASD] Move   [Enter] Talk / check   [Tab] Menu")
	hints.mark_seen(TutorialHints.MOVE)
	assert_str(hints.controls_text(glyphs)).is_equal("[Enter] Talk / check   [Tab] Menu")
	hints.mark_seen(TutorialHints.TALK)
	hints.mark_seen(TutorialHints.MENU)
	assert_str(hints.controls_text(glyphs)).is_empty()


func test_controls_strip_uses_pad_labels_on_a_pad() -> void:
	var hints := _hints(WorldState.new())
	var glyphs := PromptGlyphs.new(load(BattleMode.BINDINGS_PATH) as InputBindings,
			PromptGlyphs.DEVICE_PAD, &"xbox")
	assert_str(hints.controls_text(glyphs)).starts_with("[Left stick] Move   [A] Talk / check")


func test_settings_schema_has_the_toggle_on_by_default() -> void:
	var schema := SettingsSchema.new()
	assert_bool(schema.has_key(&"tutorial_hints")).is_true()
	assert_bool(schema.default_of(&"tutorial_hints")).is_true()
