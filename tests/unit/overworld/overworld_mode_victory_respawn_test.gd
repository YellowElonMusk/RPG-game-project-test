## Story 043, AC-18: Victory resolves the symbol in `on_thawed` per its
## record's respawn policy -- `on_map_reenter` is absent until a MapExit
## reload, `never` stays absent across any number of reloads (GDD rule 7).
extends GdUnitTestSuite

const _MAP: String = "map_fixture_street"
const _ENC: String = "enc_fixture_clerk"
const _SYM: String = "sym_fixture_clerk_1"
const _LEADER: Vector2 = Vector2(2.5, 5.5)
const _SYMBOL: Vector2 = Vector2(6.5, 5.5)


func test_on_map_reenter_absent_until_reload_then_present() -> void:
	var ws := WorldState.new()
	ws.on_map_entered(_MAP, WorldState.EntryKind.MAP_ENTRY)
	var mode: OverworldMode = _win(ws, true)
	assert_int(mode.get_symbol_brains().size()).is_equal(0)
	assert_bool(ws.is_resolved(_MAP, _SYM)).is_true()
	# Same visit: re-registering the marker is refused.
	assert_object(mode.add_symbol(_ENC, _brain(), _SYM)).is_null()
	# MapExit reload.
	ws.on_map_entered(_MAP, WorldState.EntryKind.MAP_ENTRY)
	assert_bool(ws.is_resolved(_MAP, _SYM)).is_false()
	var next: OverworldMode = _visit(ws, true)
	assert_object(next.add_symbol(_ENC, _brain(), _SYM)).is_not_null()


func test_never_stays_absent_after_two_reloads() -> void:
	var ws := WorldState.new()
	ws.on_map_entered(_MAP, WorldState.EntryKind.MAP_ENTRY)
	_win(ws, false)
	for i in 2:
		ws.on_map_entered(_MAP, WorldState.EntryKind.MAP_ENTRY)
		var next: OverworldMode = _visit(ws, false)
		assert_bool(ws.is_resolved(_MAP, _SYM)).is_true()
		assert_object(next.add_symbol(_ENC, _brain(), _SYM)).override_failure_message(
				"reload %d respawned a never symbol" % i).is_null()


func test_continue_does_not_respawn() -> void:
	var ws := WorldState.new()
	ws.on_map_entered(_MAP, WorldState.EntryKind.MAP_ENTRY)
	_win(ws, true)
	ws.on_map_entered(_MAP, WorldState.EntryKind.CONTINUE)
	assert_bool(ws.is_resolved(_MAP, _SYM)).is_true()


func test_resolution_written_in_on_thawed_not_before() -> void:
	var ws := WorldState.new()
	ws.on_map_entered(_MAP, WorldState.EntryKind.MAP_ENTRY)
	var mode: OverworldMode = _visit(ws, true)
	var source: EncounterSource = mode.add_symbol(_ENC, _brain(), _SYM)
	mode.start_encounter(_ENC, source)
	assert_bool(ws.is_resolved(_MAP, _SYM)).is_false()
	assert_int(mode.get_symbol_brains().size()).is_equal(1)
	mode.on_thawed(_ENC, GameStateMachine.BattleResult.VICTORY)
	assert_bool(ws.is_resolved(_MAP, _SYM)).is_true()
	assert_bool(mode.pending_thaw).is_true()


func test_other_maps_keep_their_resolutions_on_reload() -> void:
	var ws := WorldState.new()
	ws.mark_resolved("map_fixture_other", _SYM, WorldState.Respawn.ON_MAP_REENTER)
	ws.on_map_entered(_MAP, WorldState.EntryKind.MAP_ENTRY)
	assert_bool(ws.is_resolved("map_fixture_other", _SYM)).is_true()


func _win(ws: WorldState, respawns: bool) -> OverworldMode:
	var mode: OverworldMode = _visit(ws, respawns)
	var source: EncounterSource = mode.add_symbol(_ENC, _brain(), _SYM)
	assert_int(mode.start_encounter(_ENC, source)).is_equal(GameStateMachine.RequestResult.OK)
	mode.on_thawed(_ENC, GameStateMachine.BattleResult.VICTORY)
	return mode


func _visit(ws: WorldState, respawns: bool) -> OverworldMode:
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(
			RequestSpyMachine.new(), OverworldConfig.new(), _LEADER, [_ENC]))
	(mode.encounter_catalog.get_record(&"encounter", _ENC) as EncounterData).respawn = respawns
	mode.world_state = ws
	return mode


func _brain() -> SymbolBrain:
	return ContactFixture.brain([_SYMBOL], 0, OverworldConfig.new(), true)
