## ADR-0009 §2-6 (story 090's prerequisite): `SaveService` writes hashed
## two-line JSON atomically, reads with integrity, format and version
## checks, falls back to the backup, preflights without side effects and
## commits in registration order. Driven on an in-memory file system.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")


## A participant holding one int and one string, for round trips.
class CounterParticipant extends SaveParticipant:
	var count: int = 0
	var label: String = ""
	var fail_stage: bool = false
	var commits: int = 0

	func save_key() -> StringName:
		return &"counter"

	func schema_version() -> int:
		return 2

	func capture() -> Dictionary:
		return {"count": count, "label": label}

	func migrate(data: Dictionary, from_version: int) -> Dictionary:
		if from_version < 2 and not data.has("label"):
			data["label"] = "migrated"
		return data

	func stage(_data: Dictionary, reader: SaveReader) -> SaveStage:
		if fail_stage:
			return SaveStage.failure("refused")
		return SaveStage.success([reader.get_int("count"), reader.get_string("label")])

	func commit(staged: SaveStage) -> void:
		count = staged.staged[0]
		label = staged.staged[1]
		commits += 1

	func reset_to_new_game() -> void:
		count = 0
		label = ""


func test_round_trip_restores_every_participant() -> void:
	var ctx: Array = _service()
	var service: SaveService = ctx[0]
	var p: CounterParticipant = ctx[2]
	p.count = 7
	p.label = "seven"
	assert_int(service.save_to_slot(1)).is_equal(SaveService.SaveResult.OK)
	p.count = 0
	p.label = ""
	var loaded: LoadedSave = service.preflight(service.read_slot(1))
	assert_bool(loaded.is_ok()).is_true()
	assert_int(p.commits).is_equal(0)  # preflight has no side effects
	assert_bool(service.commit_if_loaded(loaded)).is_true()
	assert_int(p.count).is_equal(7)
	assert_str(p.label).is_equal("seven")


func test_file_is_a_header_hashing_the_exact_body_bytes() -> void:
	var ctx: Array = _service()
	var service: SaveService = ctx[0]
	var fs: MemorySaveFileSystem = ctx[1]
	service.save_to_slot(1)
	var text: String = fs.files[service.slot_path(1)]
	var lines: PackedStringArray = text.split("\n", true, 1)
	var header: Dictionary = JSON.parse_string(lines[0])
	assert_str(header["format"]).is_equal("gbtyp_save")
	assert_str(header["body_sha256"]).is_equal(lines[1].sha256_text())
	assert_int(int(header["body_bytes"])).is_equal(lines[1].to_utf8_buffer().size())


func test_a_changed_body_reads_as_corrupt() -> void:
	var ctx: Array = _service()
	var service: SaveService = ctx[0]
	var fs: MemorySaveFileSystem = ctx[1]
	(ctx[2] as CounterParticipant).count = 7
	service.save_to_slot(1)
	fs.files[service.slot_path(1)] = (fs.files[service.slot_path(1)] as String).replace("7", "9")
	assert_int(service.read_slot(1).status).is_equal(SaveService.LoadStatus.CORRUPT)


func test_format_version_size_and_missing_are_refused() -> void:
	var ctx: Array = _service()
	var service: SaveService = ctx[0]
	var fs: MemorySaveFileSystem = ctx[1]
	assert_int(service.read_slot(2).status).is_equal(SaveService.LoadStatus.EMPTY)
	fs.files[service.slot_path(2)] = '{"format":"other","version":1}\n{}'
	assert_int(service.read_slot(2).status).is_equal(SaveService.LoadStatus.WRONG_FORMAT)
	fs.files[service.slot_path(2)] = '{"format":"gbtyp_save","version":99}\n{}'
	assert_int(service.read_slot(2).status).is_equal(SaveService.LoadStatus.TOO_NEW)
	(ctx[3] as SaveConfig).max_file_bytes = 8
	assert_int(service.read_slot(2).status).is_equal(SaveService.LoadStatus.TOO_LARGE)


func test_a_failed_write_or_verify_or_rename_keeps_the_previous_save() -> void:
	var ctx: Array = _service()
	var service: SaveService = ctx[0]
	var fs: MemorySaveFileSystem = ctx[1]
	var p: CounterParticipant = ctx[2]
	p.count = 1
	service.save_to_slot(1)
	var good: String = fs.files[service.slot_path(1)]
	p.count = 2
	fs.fail_write = true
	assert_int(service.save_to_slot(1)).is_equal(SaveService.SaveResult.WRITE_FAILED)
	fs.fail_write = false
	fs.corrupt_readback = "torn"
	assert_int(service.save_to_slot(1)).is_equal(SaveService.SaveResult.VERIFY_FAILED)
	fs.corrupt_readback = ""
	fs.fail_rename = true
	assert_int(service.save_to_slot(1)).is_equal(SaveService.SaveResult.RENAME_FAILED)
	assert_str(fs.files[service.slot_path(1)]).is_equal(good)


func test_second_save_keeps_the_first_as_backup_and_backup_is_read_when_main_is_gone() -> void:
	var ctx: Array = _service()
	var service: SaveService = ctx[0]
	var fs: MemorySaveFileSystem = ctx[1]
	var p: CounterParticipant = ctx[2]
	p.count = 1
	service.save_to_slot(1)
	p.count = 2
	service.save_to_slot(1)
	fs.files.erase(service.slot_path(1))
	var loaded: LoadedSave = service.preflight(service.read_slot(1))
	assert_bool(loaded.from_backup).is_true()
	service.commit_if_loaded(loaded)
	assert_int(p.count).is_equal(1)


func test_not_a_safe_moment_refuses_the_save() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var ctx: Array = _service(machine)
	machine.open_overlay(GameStateMachine.OverlayKind.DIALOGUE)
	assert_int((ctx[0] as SaveService).save_to_slot(1)).is_equal(SaveService.SaveResult.NOT_SAFE_MOMENT)


func test_failed_stage_blocks_the_load_and_the_commit() -> void:
	var ctx: Array = _service()
	var service: SaveService = ctx[0]
	var p: CounterParticipant = ctx[2]
	p.count = 5
	service.save_to_slot(1)
	p.fail_stage = true
	var loaded: LoadedSave = service.preflight(service.read_slot(1))
	assert_int(loaded.status).is_equal(SaveService.LoadStatus.STAGE_FAILED)
	assert_str(", ".join(loaded.report)).contains("refused")
	assert_bool(service.commit_if_loaded(loaded)).is_false()


func test_old_sections_migrate_and_unknown_sections_are_written_back() -> void:
	var ctx: Array = _service()
	var service: SaveService = ctx[0]
	var fs: MemorySaveFileSystem = ctx[1]
	var p: CounterParticipant = ctx[2]
	var body: String = JSON.stringify({"playtime_s": 12, "summary": {}, "sections": {
			"counter": {"v": 1, "data": {"count": 4}},
			"from_the_future": {"v": 3, "data": {"keep": true}}}}, "", true)
	fs.files[service.slot_path(3)] = JSON.stringify({"format": "gbtyp_save", "version": 1,
			"body_sha256": body.sha256_text(), "body_bytes": body.length()}) + "\n" + body
	var loaded: LoadedSave = service.preflight(service.read_slot(3))
	assert_bool(service.commit_if_loaded(loaded)).is_true()
	assert_int(p.count).is_equal(4)
	assert_str(p.label).is_equal("migrated")
	assert_float(service.playtime_s()).is_equal(12.0)
	service.save_to_slot(3)
	assert_str(fs.files[service.slot_path(3)]).contains("from_the_future")


func test_reader_types() -> void:
	var r := SaveReader.new({"a": 2.0, "b": 1.5, "v": [1, 2.5], "s": 3})
	assert_int(r.get_int("a")).is_equal(2)
	assert_int(r.get_int("b", -1)).is_equal(-1)
	assert_vector(r.get_vector2("v")).is_equal(Vector2(1, 2.5))
	assert_str(r.get_string("s", "x")).is_equal("x")
	assert_int(r.dropped.size()).is_equal(2)


func test_duplicate_save_keys_register_once() -> void:
	var service: SaveService = auto_free(SaveService.new())
	var participants: Array[SaveParticipant] = [CounterParticipant.new(), CounterParticipant.new()]
	service.setup(null, null, MemorySaveFileSystem.new(), SaveConfig.new(), participants, Callable())
	assert_int(service.get("_participants").size()).is_equal(1)


## [service, fs, participant, config]; `machine` defaults to none (always safe).
func _service(machine: GameStateMachine = null) -> Array:
	var service: SaveService = auto_free(SaveService.new())
	var fs := MemorySaveFileSystem.new()
	var config := SaveConfig.new()
	var p := CounterParticipant.new()
	var participants: Array[SaveParticipant] = [p]
	service.setup(machine, null, fs, config, participants, func() -> int: return 1792700000)
	return [service, fs, p, config]
