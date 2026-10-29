## Story 049, AC-21 (R7 x game-state-scene-flow AC-11): a mid-chase
## Overworld survives the real OVERWORLD -> BATTLE -> OVERWORLD sequence
## (real `GameStateMachine` + `ModeHostSceneLoader`, freeze by detach) with
## every field equal to the pre-freeze snapshot except those GDD rule 7
## changes: the stunned and pushed symbol (Fled) or the resolved one
## (Victory), grace started, the followers re-formed behind the leader (story
## 007), and every Noticing
## or Chasing symbol switched to Returning. Liberated-marker sets and payoffs
## do not exist yet (stories 050, 052), so they are not in the snapshot.
##
## The mode's own `_process` is disabled; the test steps it with
## `step_frame()` so no wall-clock frame advances a timer between snapshots.
extends GdUnitTestSuite

const _SCENE: String = "res://tests/integration/overworld/fixtures/thaw_overworld_mode.tscn"
const _BATTLE_SCENE: String = "res://tests/unit/game_state/fixtures/stub_battle_mode.tscn"
const _MAP: String = "map_fixture_street"
const _ENC_A: String = "enc_fixture_fought"
const _ENC_B: String = "enc_fixture_chaser"
const _ENC_C: String = "enc_fixture_noticer"
const _ENC_D: String = "enc_fixture_patroller"
const _FACTION: String = "bureaucratia"
const _LEADER: Vector2 = Vector2(3.5, 5.5)
const _DT: float = 0.05
const _FOLLOWERS: int = 2


func test_fled_round_trip_preserves_snapshot_except_rule_7() -> void:
	await _run(GameStateMachine.BattleResult.FLED)


func test_victory_round_trip_preserves_snapshot_except_rule_7() -> void:
	await _run(GameStateMachine.BattleResult.VICTORY)


func _run(outcome: GameStateMachine.BattleResult) -> void:
	var ocfg := OverworldConfig.new()
	var ws := WorldState.new()
	ws.on_map_entered(_MAP, WorldState.EntryKind.MAP_ENTRY)
	var catalog_double := RecordCatalogDouble.new()
	for id: String in [_ENC_A, _ENC_B, _ENC_C, _ENC_D]:
		var rec: EncounterData = RecordCatalogDouble.make_encounter(id)
		rec.faction_id = _FACTION
		rec.is_boss = false
		rec.can_flee = true
		rec.respawn = true
		catalog_double.add(&"encounter", rec)

	# Arrange: the real machine and loader, as in game-state story 014.
	var recorder := SequenceRecorder.new()
	var mode_host := Node.new()
	add_child(mode_host)
	auto_free(mode_host)
	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	cfg.mode_scene_paths = {
		GameStateMachine.Mode.OVERWORLD: _SCENE,
		GameStateMachine.Mode.BATTLE: _BATTLE_SCENE,
	}
	var outcome_box: Array = [-1]
	var machine_box: Array = [null]
	var pre_setup := func(mode: GameMode, payload: RefCounted) -> void:
		if mode is StubBattleMode:
			(mode as StubBattleMode).snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
		elif mode is OverworldMode:
			var ow := mode as OverworldMode
			ow.config = ocfg
			ow.setup(machine_box[0], payload)
			ow.set_walk_grid(ContactFixture.open_grid())
			ow.set_leader_position(_LEADER)
			ow.encounter_catalog = catalog_double
			ow.world_state = ws
			ow.set_process(false)  # _ready() re-enables it; set again below.
	var loader := ModeHostSceneLoader.new(mode_host, cfg, SpyGameStateLog.new(), pre_setup,
			func() -> int: return outcome_box[0])
	var machine := GameStateMachine.new(loader, StubTransitionPresenter.new(recorder), cfg,
			GameStateFixtures.make_ready_catalog(), QuitSpy.new(recorder).as_callable(),
			SpyGameStateLog.new())
	machine_box[0] = machine
	machine.mode_entered.connect(loader.on_mode_entered)
	machine.tick(0.0)
	machine.tick(cfg.t_out[&"fade"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"fade"])
	machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)
	machine.tick(cfg.t_out[&"fade"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"fade"])
	var mode: OverworldMode = loader.current_mode_node() as OverworldMode
	assert_object(mode).is_not_null()
	mode.set_process(false)  # _ready() re-enabled _process; the test steps frames.
	assert_bool(mode.is_exploring()).is_true()

	# A mid-chase scene: map-load grace lapses, then B notices and chases,
	# C has just noticed, D patrols (deaf, cooldown running), A is fought.
	mode.step_frame(ocfg.encounter_grace_s + _DT, Vector2.ZERO)
	var a: EncounterSource = mode.add_symbol(_ENC_A,
			ContactFixture.brain([Vector2(9.5, 2.5)], 0, ocfg, true))
	mode.add_symbol(_ENC_D, ContactFixture.brain(
			[Vector2(0.5, 1.5), Vector2(0.5, 8.5)], 3, ocfg, true))
	var b: SymbolBrain = SymbolBrain.new(PackedVector2Array([Vector2(1.5, 7.0)]),
			SymbolBrain.PathMode.LOOP, 1)
	mode.add_symbol(_ENC_B, b)
	mode.step_frame(_DT, Vector2.ZERO)
	mode.step_frame(ocfg.notice_delay_s, Vector2.ZERO)
	var c: SymbolBrain = SymbolBrain.new(PackedVector2Array([Vector2(2.0, 7.5)]),
			SymbolBrain.PathMode.LOOP, 2)
	mode.add_symbol(_ENC_C, c)
	mode.step_frame(_DT, Vector2.ZERO)
	mode.step_followers(_FOLLOWERS)
	assert_int(b.sub_state).is_equal(SymbolBrain.SubState.CHASING)
	assert_int(c.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
	assert_int(mode.get_state()).is_equal(OverworldMode.State.EXPLORING)

	# Act: the real encounter request, then the battle and its outcome.
	assert_int(mode.start_encounter(_ENC_A, a)).is_equal(GameStateMachine.RequestResult.OK)
	var before: Dictionary = _snapshot(mode)
	var a_before: Vector2 = a.brain.position
	machine.tick(cfg.t_out[&"battle_wipe"])
	machine.tick(1.0 / 60.0)
	machine.tick(cfg.t_in[&"battle_wipe"])
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
	assert_bool(mode.is_inside_tree()).is_false()
	outcome_box[0] = outcome
	assert_int(machine.report_battle_outcome(outcome)).is_equal(GameStateMachine.RequestResult.OK)
	if outcome == GameStateMachine.BattleResult.VICTORY:
		assert_int(machine.report_results_done()).is_equal(GameStateMachine.RequestResult.OK)
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		await get_tree().process_frame
		ticks += 1
	assert_bool(ticks < 600).is_true()

	# Assert: the same instance, Exploring, grace just started.
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	assert_bool(is_same(loader.current_mode_node(), mode)).is_true()
	assert_int(mode.get_state()).is_equal(OverworldMode.State.EXPLORING)
	var expected: Dictionary = before.duplicate(true)
	expected["grace_left"] = ocfg.encounter_grace_s
	# Rule 7: every Noticing or Chasing symbol is Returning once grace starts.
	for key: String in [_ENC_B, _ENC_C]:
		expected["brains"][key]["sub_state"] = SymbolBrain.SubState.RETURNING
		expected["brains"][key]["giveup"] = 0.0
	if outcome == GameStateMachine.BattleResult.FLED:
		var dir: Vector2 = (a_before - _LEADER).normalized()
		var push: float = SymbolBrain.push_distance(mode.get_walk_grid(), a_before, dir,
				ocfg.flee_push_m, ocfg.body_radius)
		assert_float(push).is_greater(0.0)
		expected["brains"][_ENC_A]["sub_state"] = SymbolBrain.SubState.STUNNED
		expected["brains"][_ENC_A]["position"] = a_before + dir * push
		expected["brains"][_ENC_A]["stun"] = ocfg.flee_grace_s
	else:
		(expected["brains"] as Dictionary).erase(_ENC_A)
		assert_bool(ws.is_resolved(_MAP, _ENC_A)).is_true()
	var actual: Dictionary = _snapshot(mode)
	# Story 007: the thaw re-forms the followers at spacing behind the leader,
	# opposite its facing (checked to a tolerance, then excluded from the diff).
	var followers: Array[Vector2] = actual["followers"]
	assert_int(followers.size()).is_equal(ocfg.max_followers)
	for i: int in followers.size():
		var want: Vector2 = _LEADER - mode.get_leader_facing() * float(i + 1) * ocfg.follower_spacing_m
		assert_vector(followers[i]).is_equal_approx(want, Vector2.ONE * 1e-4)
	expected["followers"] = followers
	var diffs: Array[String] = []
	_diff("", expected, actual, diffs)
	assert_array(diffs).override_failure_message("snapshot mismatch: %s" % [diffs]).is_empty()


## Appends `path: expected != actual` for every leaf that differs.
func _diff(path: String, expected: Variant, actual: Variant, out: Array[String]) -> void:
	if expected is Dictionary and actual is Dictionary:
		var keys: Array = (expected as Dictionary).keys()
		for k: Variant in (actual as Dictionary).keys():
			if not keys.has(k):
				keys.append(k)
		for k: Variant in keys:
			_diff("%s/%s" % [path, k], (expected as Dictionary).get(k), (actual as Dictionary).get(k), out)
	elif var_to_str(expected) != var_to_str(actual):
		out.append("%s: %s != %s" % [path, var_to_str(expected), var_to_str(actual)])


## Every Overworld-side field this round trip must preserve, keyed by enc ID.
func _snapshot(mode: OverworldMode) -> Dictionary:
	var brains: Dictionary = {}
	for b: SymbolBrain in mode.get_symbol_brains():
		brains[_enc_of(b)] = {
			"sub_state": b.sub_state, "position": b.position, "facing": b.facing,
			"heading": b.heading, "next": b.next_index(), "dir": b.direction(),
			"stun": b.stun_left(), "notice": b.notice_elapsed(), "cooldown": b.cooldown_left(),
			"giveup": b.giveup_elapsed(), "resume": b.resume_point(),
			"pausing": b.is_turn_pausing(), "contact_pending": b.contact_pending,
		}
	return {
		"leader": mode.get_leader_position(), "leader_facing": mode.get_leader_facing(),
		"followers": mode.get_follower_positions(), "grace_left": mode.get_grace_left(),
		"brains": brains,
	}


func _enc_of(b: SymbolBrain) -> String:
	return [_ENC_A, _ENC_B, _ENC_C, _ENC_D][b.marker_index]
