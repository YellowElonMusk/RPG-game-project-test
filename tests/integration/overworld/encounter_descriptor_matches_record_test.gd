## Story 039, AC-14: contact with a symbol whose `enc_` record is a fixture
## hands the real `GameStateMachine` a descriptor equal to the record, field
## for field (captured at the loader's `begin_swap`).
extends GdUnitTestSuite

const _ENC: String = "enc_fixture_descriptor"


func test_descriptor_reaching_game_state_matches_record() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var tcfg: TransitionConfig = env["config"]
	var rec: EncounterData = RecordCatalogDouble.make_encounter(_ENC)
	(env["catalog"] as StubCatalog).set_known(&"faction", rec.faction_id, true)
	var cfg := OverworldConfig.new()
	var leader := Vector2(2.0, 5.0)
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(machine, cfg, leader, [_ENC]))
	mode.add_symbol(_ENC, ContactFixture.brain(
			[leader + Vector2(cfg.body_radius, 0.0)], 0, cfg, true))
	var swaps_before: int = loader.begin_swap_count

	mode.step_frame(1.0 / 60.0, Vector2.ZERO)
	assert_int(mode.get_state()).is_equal(OverworldMode.State.FROZEN)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	machine.tick(tcfg.t_out[&"battle_wipe"])
	machine.tick(0.0)

	assert_int(loader.begin_swap_count).is_equal(swaps_before + 1)
	var payload: BattleEntryPayload = loader.last_begin_swap_args[2] as BattleEntryPayload
	assert_object(payload).is_not_null()
	var d: EncounterDescriptor = payload.descriptor
	assert_str(d.encounter_id).is_equal(rec.id)
	assert_array(Array(d.enemy_ids)).is_equal(Array(rec.enemy_ids))
	assert_str(d.battle_stage_id).is_equal(rec.battle_stage_id)
	assert_str(d.faction_id).is_equal(rec.faction_id)
	assert_bool(d.is_boss).is_equal(rec.is_boss)
	assert_bool(d.can_flee).is_equal(rec.can_flee)
	assert_bool(d.retreat_allowed).is_equal(rec.retreat_allowed)
