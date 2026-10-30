## Story 111, AC-45b (UI): the map name card appears on a map load's reveal
## and never after a thaw or a redirect; it is fully shown at
## `text_hold(text) - dt` after the reveal and fading at `+ dt`; a story
## Dialogue due on the same load opens after it fades; its text never holds
## a stage word.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _SEGMENT: String = "res://data/maps/paris_segment_placeholder.tscn"
const _DT: float = 1.0 / 60.0


func test_card_shows_on_a_load_reveal_and_holds_for_text_hold() -> void:
	var ctx: Array = _loaded_during_a_transition()
	var mode: OverworldMode = ctx[1]
	assert_int(mode.name_card_phase).is_equal(OverworldMode.CardPhase.SHOWN)
	assert_str(mode.name_card_text).is_equal("Paris - Rue de Rivoli")
	var hold: float = mode.config.text_hold(mode.name_card_text)
	mode.tick_timed_text(hold - _DT)
	assert_int(mode.name_card_phase).is_equal(OverworldMode.CardPhase.SHOWN)
	mode.tick_timed_text(2.0 * _DT)
	assert_int(mode.name_card_phase).is_equal(OverworldMode.CardPhase.FADING)
	mode.tick_timed_text(mode.config.text_fade_s)
	assert_int(mode.name_card_phase).is_equal(OverworldMode.CardPhase.HIDDEN)
	assert_bool(mode.name_card_showing).is_false()


func test_card_waits_for_the_reveal() -> void:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode: OverworldMode = _mode(machine)
	machine.request_in_mode_fade(func() -> void: pass)
	mode.load_map((load(_SEGMENT) as PackedScene).instantiate() as OverworldMap)
	assert_int(mode.name_card_phase).is_equal(OverworldMode.CardPhase.HIDDEN)
	_run_to_idle(machine)
	assert_int(mode.name_card_phase).is_equal(OverworldMode.CardPhase.SHOWN)


func test_no_card_after_a_thaw_or_a_redirect() -> void:
	var ctx: Array = _loaded_during_a_transition()
	var machine: GameStateMachine = ctx[0]
	var mode: OverworldMode = ctx[1]
	mode.tick_timed_text(60.0)
	# A redirect: the same-instance fade, no map load.
	assert_int(mode.redirect_leader(Vector2(12.0, 14.5), Vector2.UP)).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(mode.name_card_phase).is_equal(OverworldMode.CardPhase.HIDDEN)
	# A thaw's reveal: transition_finished with no map load.
	machine.transition_finished.emit(GameStateMachine.Mode.OVERWORLD)
	assert_int(mode.name_card_phase).is_equal(OverworldMode.CardPhase.HIDDEN)


func test_a_story_line_due_on_the_load_waits_for_the_card() -> void:
	var ctx: Array = _loaded_during_a_transition()
	var mode: OverworldMode = ctx[1]
	mode.say_after_name_card("A story line.")
	assert_array(mode.lines_said).is_empty()
	mode.tick_timed_text(mode.config.text_hold(mode.name_card_text))
	assert_array(mode.lines_said).is_empty()  # fading still counts
	mode.tick_timed_text(mode.config.text_fade_s + _DT)
	assert_array(mode.lines_said).is_equal(["A story line."])


func test_the_card_never_shows_a_stage_word() -> void:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode: OverworldMode = _mode(machine)
	var rec: MapData = (load("res://data/maps/map_paris_segment_placeholder.tres") as MapData).duplicate()
	rec.display_name = "Rue des Formulaires Occupied"
	(mode.encounter_catalog as RecordCatalogDouble).add(&"map", rec)
	mode.load_map((load(_SEGMENT) as PackedScene).instantiate() as OverworldMap)
	for word: String in OverworldMode.STAGE_WORDS:
		assert_bool(mode.name_card_text.contains(word)).is_false()
	assert_str(mode.name_card_text).is_equal("Rue des Formulaires")


## [machine, mode] with the segment loaded inside a transition, revealed.
func _loaded_during_a_transition() -> Array:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode: OverworldMode = _mode(machine)
	machine.request_in_mode_fade(func() -> void: pass)
	mode.load_map((load(_SEGMENT) as PackedScene).instantiate() as OverworldMap)
	_run_to_idle(machine)
	return [machine, mode]


func _mode(machine: GameStateMachine) -> OverworldMode:
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	auto_free(mode)
	mode.setup(machine, null)
	mode.world_state = WorldState.new()
	var catalog := RecordCatalogDouble.new()
	catalog.add(&"map", load("res://data/maps/map_paris_segment_placeholder.tres"))
	mode.encounter_catalog = catalog
	return mode


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
