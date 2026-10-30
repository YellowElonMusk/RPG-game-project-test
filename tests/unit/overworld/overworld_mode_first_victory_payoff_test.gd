## Story 050, AC-21b (GDD rule 7a): a first Victory over a symbol grants its
## record's payoff: `clue` adds one Codex rumour and queues its interim stub
## line, `open` opens the linked checkpoint, `item` adds the item. On the
## reveal (`transition_finished`) the payoff card shows one line naming the
## result. A second Victory over the respawned Clerk grants nothing and
## shows no card.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _ENC: String = "enc_fixture_payoff"
const _SYM: String = "sym_fixture_payoff"
const _MAP: String = "map_fixture"


func test_clue_adds_one_rumour_and_names_it_on_the_card() -> void:
	var mode: OverworldMode = _mode({"type": "clue", "facet": "facet_fixture", "text": "Rumour: fixture."})
	_win(mode)
	assert_int(mode.rumours_added).is_equal(1)
	assert_bool(mode.has_rumour("facet_fixture")).is_true()
	assert_str(mode.payoff_card_text).is_equal("Rumour noted in the Codex")
	assert_array(mode.lines_said).is_empty()  # the stub waits for the card


func test_open_opens_the_linked_checkpoint() -> void:
	var mode: OverworldMode = _mode({"type": "open", "checkpoint": "cp_fixture_pocket", "label": "Rue des Tampons"})
	var cp: CheckpointMarker = auto_free(CheckpointMarker.new())
	cp.marker_id = &"cp_fixture_pocket"
	cp.requirement_item_id = "item_fixture_key"
	cp.blocked_rect = Rect2(9, 2, 1, 1)
	mode.add_checkpoint(cp)
	_win(mode)
	assert_bool(mode.is_checkpoint_open(&"cp_fixture_pocket")).is_true()
	assert_str(mode.payoff_card_text).is_equal("Shortcut opened: Rue des Tampons")


func test_item_adds_the_item_and_meets_a_checkpoint_requirement() -> void:
	var mode: OverworldMode = _mode({"type": "item", "item_id": "item_form_27b", "label": "Form 27-B"})
	var cp: CheckpointMarker = auto_free(CheckpointMarker.new())
	cp.marker_id = &"cp_fixture_gate"
	cp.requirement_item_id = "item_form_27b"
	cp.blocked_rect = Rect2(9, 2, 1, 1)
	mode.add_checkpoint(cp)
	_win(mode)
	assert_int(mode.items_added).is_equal(1)
	assert_str(mode.payoff_card_text).is_equal("Got: Form 27-B")
	mode.tick_timed_text(60.0)
	mode.confirm_checkpoint(&"cp_fixture_gate")
	assert_bool(mode.is_checkpoint_open(&"cp_fixture_gate")).is_true()


func test_a_respawned_clerk_grants_nothing_and_shows_no_card() -> void:
	var mode: OverworldMode = _mode({"type": "clue", "facet": "facet_fixture", "text": "Rumour: fixture."})
	_win(mode)
	mode.tick_timed_text(60.0)
	var machine: GameStateMachine = mode.get("_machine")
	machine.close_overlay()  # the stub line
	# Leave and come back: the on_map_reenter Clerk respawns.
	mode.world_state.on_map_entered(_MAP, WorldState.EntryKind.MAP_ENTRY)
	assert_object(mode.add_symbol(_ENC, ContactFixture.brain([Vector2(8.5, 5.5)], 0, mode.config, true), _SYM)).is_not_null()
	mode.on_thawed(_ENC, GameStateMachine.BattleResult.VICTORY)
	machine.transition_finished.emit(GameStateMachine.Mode.OVERWORLD)
	assert_int(mode.rumours_added).is_equal(1)
	assert_int(mode.payoff_card_phase).is_equal(OverworldMode.CardPhase.HIDDEN)
	assert_str(mode.payoff_card_text).is_empty()


func test_none_grants_nothing_and_shows_no_card() -> void:
	var mode: OverworldMode = _mode({"type": "none"})
	_win(mode)
	assert_int(mode.payoff_card_phase).is_equal(OverworldMode.CardPhase.HIDDEN)


## A Victory over the fixture symbol, then the reveal.
func _win(mode: OverworldMode) -> void:
	mode.on_thawed(_ENC, GameStateMachine.BattleResult.VICTORY)
	(mode.get("_machine") as GameStateMachine).transition_finished.emit(GameStateMachine.Mode.OVERWORLD)


func _mode(payoff: Dictionary) -> OverworldMode:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(
			machine, OverworldConfig.new(), Vector2(2.5, 5.5), [_ENC]))
	var rec: EncounterData = mode.encounter_catalog.get_record(&"encounter", _ENC)
	rec.victory_payoff = payoff
	rec.respawn = true
	mode.world_state = WorldState.new()
	mode.world_state.on_map_entered(_MAP, WorldState.EntryKind.MAP_ENTRY)
	mode.add_symbol(_ENC, ContactFixture.brain([Vector2(8.5, 5.5)], 0, mode.config, true), _SYM)
	return mode
