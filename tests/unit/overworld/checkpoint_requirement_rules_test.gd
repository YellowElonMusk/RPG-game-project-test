## Story 073, AC-29 (GDD rules 10 and 0): every checkpoint has exactly one
## requirement whose `obtained_at` resolves; every critical-path leg can be
## walked opening checkpoints only from fight-free sources reached earlier
## on the leg (a Victory never counts; a chapter-step source counts when set
## on or before the leg's step); only the story encounter's checkpoint may
## have the `encounter` outcome on the critical path; return markers are
## SAFE and outside every MapExit.
extends GdUnitTestSuite

const _SEGMENT_ID: String = "map_paris_segment_placeholder"
const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]
## A gate over the segment's dungeon exit (cells x 18-22, rows 1-2), clear
## of the dungeon-side EntryPoint (row 3).
const _GATE: Rect2 = Rect2(18, 1, 5, 2)


func test_the_shipped_checkpoints_pass() -> void:
	var maps: Dictionary = {}
	var records: Dictionary = {}
	for name: String in _MAPS:
		var id: String = "map_paris_%s_placeholder" % name
		maps[id] = _scene(name)
		records[id] = load("res://data/maps/%s.tres" % id)
	assert_array(Array(CheckpointRules.check(maps, records, _steps(), _catalog(), OverworldConfig.new()))).is_empty()


func test_exactly_one_requirement() -> void:
	var both: CheckpointMarker = _gate("step_leave_town")
	both.requirement_item_id = "item_fixture"
	assert_str(_errors(both)).contains("needs exactly one requirement")
	var neither: CheckpointMarker = _gate("step_leave_town")
	neither.requirement_flag = ""
	assert_str(_errors(neither)).contains("needs exactly one requirement")


func test_an_unresolved_source_is_named() -> void:
	assert_str(_errors(_gate("nowhere_fixture"))).contains("obtained_at 'nowhere_fixture' does not resolve")


func test_a_step_source_counts_only_on_or_before_the_legs_step() -> void:
	assert_str(_errors(_gate("step_leave_town"))).is_empty()
	assert_str(_errors(_gate("step_walk_home_a"))).contains("leg 'segment_to_dungeon': its end 'exit_to_dungeon' is unreachable")


func test_a_victory_source_never_opens_the_leg() -> void:
	assert_str(_errors(_gate("enc_paris_clerks_west"))).contains("is unreachable without a fight")


func test_a_reached_change_gag_opens_the_leg() -> void:
	var stamp: GagInteractable = ProbeFixture.gag(Vector2(6.5, 10.5), GagInteractable.Response.CHANGE, &"gag_fixture_stamp")
	assert_str(_errors(_gate("gag_fixture_stamp"), [stamp])).is_empty()


func test_an_encounter_outcome_on_the_critical_path_is_named() -> void:
	var gate: CheckpointMarker = _gate("step_leave_town")
	gate.failure_outcome = CheckpointMarker.FailureOutcome.ENCOUNTER
	gate.linked_encounter_id = "enc_paris_clerks_west"
	assert_str(_errors(gate)).contains("critical-path checkpoint 'cp_fixture_gate' has the encounter outcome")


func test_return_markers_in_a_wall_or_an_exit_are_named() -> void:
	var walled: CheckpointMarker = _gate("step_leave_town")
	walled.return_marker = Vector2(0.5, 0.5)
	assert_str(_errors(walled)).contains("is not in a walkable SAFE cell")
	var in_exit: CheckpointMarker = _gate("step_leave_town")
	in_exit.blocked_rect = Rect2(14, 12, 1, 1)
	in_exit.return_marker = Vector2(2.0, 8.0)
	assert_str(_errors(in_exit)).contains("lies inside exit 'exit_to_town'")


func _gate(obtained_at: String) -> CheckpointMarker:
	var cp := CheckpointMarker.new()
	cp.marker_id = &"cp_fixture_gate"
	cp.requirement_flag = "fixture_gate_permit"
	cp.obtained_at = obtained_at
	cp.failure_outcome = CheckpointMarker.FailureOutcome.REDIRECT
	cp.blocked_rect = _GATE
	cp.position = Vector3(20.5, 0.0, 4.0)
	cp.return_marker = Vector2(17.5, 6.5)
	return cp


func _errors(cp: CheckpointMarker, extras: Array = []) -> String:
	var map: OverworldMap = _scene("segment")
	map.add_child(cp)
	for e: Node3D in extras:
		map.add_child(e)
	var errors: PackedStringArray = CheckpointRules.check({_SEGMENT_ID: map},
			{_SEGMENT_ID: load("res://data/maps/%s.tres" % _SEGMENT_ID)}, _steps(), _catalog(), OverworldConfig.new())
	return "\n".join(errors)


func _scene(name: String) -> OverworldMap:
	return auto_free((load("res://data/maps/paris_%s_placeholder.tscn" % name) as PackedScene).instantiate())


func _steps() -> ChapterSteps:
	return load("res://data/chapters/chapter_paris_steps.tres")


func _catalog() -> RecordCatalogDouble:
	var catalog := RecordCatalogDouble.new()
	for f: String in DirAccess.get_files_at("res://data/encounters"):
		if f.ends_with(".tres"):
			catalog.add(&"encounter", load("res://data/encounters/" + f))
	return catalog
