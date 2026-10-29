## Story 088, AC-33a (GDD rule 13): walking into the Supervisor starts the
## boss encounter by contact; the boss never moved before contact, and the
## descriptor carries `is_boss = true`, `can_flee = false` and
## `retreat_allowed = true` from its record. `confirm` at it also starts it.
extends GdUnitTestSuite

const _CHAMBER: String = "res://data/maps/paris_boss_chamber_placeholder.tscn"
const _ENC: String = "enc_paris_supervisor"
const _DT: float = 1.0 / 60.0


func test_contact_starts_the_boss_fight_with_its_record_flags() -> void:
	var machine := RequestSpyMachine.new()
	var mode: OverworldMode = _mode(machine)
	var boss: SymbolBrain = mode.get_symbol_brains()[0]
	var placed: Vector2 = boss.position
	mode.grace_active = false
	var frames: int = 0
	while machine.payloads.is_empty() and frames < 600:
		mode.step_frame(_DT, Vector2.UP)
		assert_vector(boss.position).is_equal(placed)
		frames += 1
	assert_int(machine.payloads.size()).is_equal(1)
	var descriptor: EncounterDescriptor = (machine.payloads[0] as BattleEntryPayload).descriptor
	assert_str(descriptor.encounter_id).is_equal(_ENC)
	assert_bool(descriptor.is_boss).is_true()
	assert_bool(descriptor.can_flee).is_false()
	assert_bool(descriptor.retreat_allowed).is_true()
	assert_vector(boss.position).is_equal(placed)


func test_confirm_at_the_boss_also_starts_it() -> void:
	var machine := RequestSpyMachine.new()
	var mode: OverworldMode = _mode(machine)
	var boss: SymbolBrain = mode.get_symbol_brains()[0]
	mode.set_leader_position(boss.position + Vector2(0.0, 1.2))
	mode.set_leader_facing(Vector2.UP)
	assert_str(String(mode.probe_kind())).is_equal("fight")
	mode.handle_action(InputActions.CONFIRM, true)
	assert_array(machine.encounter_ids()).is_equal([_ENC])


func _mode(machine: GameStateMachine) -> OverworldMode:
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	auto_free(mode)
	mode.setup(machine, null)
	var catalog := RecordCatalogDouble.new()
	catalog.add(&"encounter", load("res://data/encounters/enc_paris_supervisor.tres"))
	mode.encounter_catalog = catalog
	mode.load_map((load(_CHAMBER) as PackedScene).instantiate() as OverworldMap)
	var entry: EntryPoint = mode.get_map().find_entry_point(&"from_dungeon")
	mode.teleport_leader(entry.ground_position(mode.get_map()), entry.facing)
	return mode
