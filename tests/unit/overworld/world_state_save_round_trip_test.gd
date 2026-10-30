## Story 095, AC-35c (GDD rule 15): save and load round-trip the last camp
## registered, opened interactables (checkpoints, and gag `change` and
## first-use state, which live in the story flags), and the interim story
## flags, through the real participants on an in-memory save folder.
## Granted payoffs, liberated sets and `stage_stored` do not exist yet
## (stories 050, 059, 053); `WorldState.to_dict()` gains them with those
## stories.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")


func test_camp_checkpoints_gags_and_flags_round_trip() -> void:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var ws := WorldState.new()
	var service: SaveService = _service(machine, ws)
	machine.register_camp("camp_paris_pre_dungeon")
	ws.on_map_entered("map_paris_dungeon_placeholder", WorldState.EntryKind.MAP_ENTRY)
	ws.party_pos = Vector2(16.5, 27.0)
	ws.party_facing = Vector2.UP
	ws.open_checkpoint("map_paris_dungeon_placeholder", &"cp_permit_boom")
	ws.set_flag("gag_changed:map_paris_segment_placeholder:gag_fixture")
	ws.set_flag("rumour:rumour_permit_ban")
	ws.set_flag("permits_mandatory")
	ws.mark_resolved("map_paris_dungeon_placeholder", "sym_paris_permit_counter", WorldState.Respawn.NEVER)
	var saved: Dictionary = ws.to_dict()
	assert_int(service.save_to_slot(1)).is_equal(SaveService.SaveResult.OK)

	# Everything changes, then the save is loaded back.
	machine.restore_last_camp_id("camp_paris_cafe")
	ws.reset_to_new_game()
	var loaded: LoadedSave = service.preflight(service.read_slot(1))
	assert_bool(loaded.is_ok()).override_failure_message(", ".join(loaded.report)).is_true()
	assert_bool(service.commit_if_loaded(loaded)).is_true()

	assert_str(machine.last_camp_id).is_equal("camp_paris_pre_dungeon")
	assert_dict(ws.to_dict()).is_equal(saved)
	assert_bool(ws.is_checkpoint_open("map_paris_dungeon_placeholder", &"cp_permit_boom")).is_true()
	assert_bool(ws.has_flag("gag_changed:map_paris_segment_placeholder:gag_fixture")).is_true()
	assert_bool(ws.is_resolved("map_paris_dungeon_placeholder", "sym_paris_permit_counter")).is_true()


func test_an_unknown_map_fails_the_load_and_changes_nothing() -> void:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var ws := WorldState.new()
	var service: SaveService = _service(machine, ws)
	ws.on_map_entered("map_paris_town_placeholder", WorldState.EntryKind.MAP_ENTRY)
	service.save_to_slot(1)
	var fs: MemorySaveFileSystem = service.get("_fs")
	var path: String = service.slot_path(1)
	var lines: PackedStringArray = (fs.files[path] as String).split("\n", true, 1)
	var body: String = lines[1].replace("map_paris_town_placeholder", "map_gone_forever")
	fs.files[path] = JSON.stringify({"format": "gbtyp_save", "version": 1,
			"body_sha256": body.sha256_text(), "body_bytes": body.length()}) + "\n" + body
	ws.set_flag("untouched")
	var loaded: LoadedSave = service.preflight(service.read_slot(1))
	assert_int(loaded.status).is_equal(SaveService.LoadStatus.STAGE_FAILED)
	assert_str(", ".join(loaded.report)).contains("map_gone_forever")
	assert_bool(ws.has_flag("untouched")).is_true()


func _service(machine: GameStateMachine, ws: WorldState) -> SaveService:
	var service: SaveService = auto_free(SaveService.new())
	var catalog := RecordCatalogDouble.new()
	for name: String in ["town", "segment", "dungeon", "boss_chamber"]:
		catalog.add(&"map", load("res://data/maps/map_paris_%s_placeholder.tres" % name))
	service.setup(machine, catalog, MemorySaveFileSystem.new(), SaveConfig.new(),
			SaveBootstrap.participants(machine, ws, Callable()), func() -> int: return 0)
	return service
