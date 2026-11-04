## Onboarding (systems index #21) on the overworld: the controls strip drops
## Move, Talk and Menu as the player does each; the café's first camp prompt
## barks the camp hint once; the first patrolling symbol within its notice
## distance barks the symbol hint once. No hints injected shows nothing.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _TOWN: String = "res://data/maps/paris_town_placeholder.tscn"
const _SEGMENT: String = "res://data/maps/paris_segment_placeholder.tscn"
const _DT: float = 1.0 / 60.0


func test_controls_strip_drops_each_part_as_it_is_done() -> void:
	var world := WorldState.new()
	var mode: OverworldMode = _mode(_TOWN, TutorialHints.new(world))
	assert_str(mode.controls_hint_text()).contains("Move")
	mode.step_frame(_DT, Vector2.RIGHT)
	assert_str(mode.controls_hint_text()).not_contains("Move")
	assert_str(mode.controls_hint_text()).contains("Talk")
	_face_cafe(mode)
	mode.handle_action(InputActions.CONFIRM, true)
	assert_bool(world.has_flag(TutorialHints.PREFIX + TutorialHints.TALK)).is_true()
	mode.call("_on_overlay_opened", GameStateMachine.OverlayKind.MENU)
	mode.handle_action(InputActions.CANCEL, true)  # close the camp prompt
	assert_str(mode.controls_hint_text()).is_empty()


func test_strip_hides_while_the_camp_prompt_is_open() -> void:
	var mode: OverworldMode = _mode(_TOWN, TutorialHints.new(WorldState.new()))
	_face_cafe(mode)
	mode.handle_action(InputActions.CONFIRM, true)
	assert_object(mode.get_camp_prompt_camp()).is_not_null()
	assert_str(mode.controls_hint_text()).is_empty()


func test_first_camp_prompt_barks_the_camp_hint_once() -> void:
	var mode: OverworldMode = _mode(_TOWN, TutorialHints.new(WorldState.new()))
	_face_cafe(mode)
	mode.handle_action(InputActions.CONFIRM, true)
	assert_str(mode.bark_text).is_equal(TutorialHints.CAMP_TEXT)
	mode.handle_action(InputActions.CANCEL, true)
	mode.bark_text = ""
	mode.handle_action(InputActions.CONFIRM, true)
	assert_str(mode.bark_text).is_empty()


func test_first_symbol_in_notice_distance_barks_the_symbol_hint_once() -> void:
	var world := WorldState.new()
	var mode: OverworldMode = _mode(_SEGMENT, TutorialHints.new(world))
	var source: EncounterSource = null
	for s: EncounterSource in mode.get_encounter_sources():
		if s.brain.contact_eligible():
			source = s
			break
	assert_object(source).is_not_null()
	mode.grace_active = true
	mode.set_leader_position(source.brain.position + Vector2(mode.config.see_m() - 0.5, 0.0))
	mode.step_frame(_DT, Vector2.ZERO)
	assert_str(mode.bark_text).is_equal(TutorialHints.SYMBOLS_TEXT)
	assert_bool(world.has_flag(TutorialHints.PREFIX + TutorialHints.SYMBOLS)).is_true()


func test_no_hints_injected_shows_nothing() -> void:
	var mode: OverworldMode = _mode(_TOWN, null)
	assert_str(mode.controls_hint_text()).is_empty()
	_face_cafe(mode)
	mode.handle_action(InputActions.CONFIRM, true)
	assert_str(mode.bark_text).is_empty()


func _face_cafe(mode: OverworldMode) -> void:
	var cafe: Vector2 = mode.get_map().camp_spots()[0].ground_position(mode.get_map())
	mode.set_leader_position(cafe + Vector2(0.0, 1.3))
	mode.set_leader_facing(Vector2.UP)


func _mode(path: String, hints: TutorialHints) -> OverworldMode:
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	mode.hints = hints
	auto_free(mode)
	mode.setup(GameStateFixtures.make_machine_in_overworld()["machine"], null)
	mode.load_map((load(path) as PackedScene).instantiate() as OverworldMap)
	return mode
