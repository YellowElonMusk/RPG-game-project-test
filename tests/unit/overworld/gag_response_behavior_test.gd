## Story 118, AC-49b (GDD rule 16): each gag response behaves as specified.
## `line` opens Dialogue; `change` plays without an overlay and is saved as
## changed (still changed after a save and load); `clue` opens Dialogue and
## adds one rumour; a `recruit_remark` is optional and the map validates
## with or without one.
extends GdUnitTestSuite

const _AT: Vector2 = ProbeFixture.OPEN_SPOT
const _AHEAD: Vector2 = ProbeFixture.OPEN_SPOT + Vector2(0.0, -1.0)
const _SEGMENT_ID: String = "map_paris_segment_placeholder"


func test_line_opens_dialogue() -> void:
	var mode: OverworldMode = _facing(ProbeFixture.gag(_AHEAD, GagInteractable.Response.LINE))
	mode.confirm()
	assert_array(mode.lines_said).is_equal(["Fixture gag."])
	assert_array(_machine(mode).overlay_stack).is_equal([GameStateMachine.OverlayKind.DIALOGUE])


func test_change_plays_without_an_overlay_and_stays_changed_across_save_and_load() -> void:
	var gag: GagInteractable = ProbeFixture.gag(_AHEAD, GagInteractable.Response.CHANGE)
	var mode: OverworldMode = _facing(gag)
	mode.confirm()
	assert_array(_machine(mode).overlay_stack).is_empty()
	assert_str(mode.bark_text).is_equal("Fixture gag.")
	assert_bool((mode.get_map().get_node("PlaceholderSet/Gag_gag_fixture") as Node3D).visible).is_false()
	var restored := WorldState.new()
	restored.from_dict(_through_json(mode.world_state.to_dict()))
	# A reload: a fresh mode on the same map with the saved WorldState.
	var again: OverworldMode = auto_free(OverworldMode.new())
	again.config = OverworldConfig.new()
	again.setup(_machine(mode), null)
	again.world_state = restored
	var map: OverworldMap = (load(ProbeFixture.SEGMENT) as PackedScene).instantiate() as OverworldMap
	map.add_child(ProbeFixture.gag(_AHEAD, GagInteractable.Response.CHANGE))
	again.load_map(map)
	ProbeFixture.stand(again, _AT, Vector2.UP)
	assert_object(again.probe()).is_null()
	assert_bool((again.get_map().get_node("PlaceholderSet/Gag_gag_fixture") as Node3D).visible).is_false()


func test_clue_opens_dialogue_and_adds_one_rumour() -> void:
	var mode: OverworldMode = _facing(ProbeFixture.gag(_AHEAD, GagInteractable.Response.CLUE))
	mode.confirm()
	assert_array(_machine(mode).overlay_stack).is_equal([GameStateMachine.OverlayKind.DIALOGUE])
	assert_int(mode.rumours_added).is_equal(1)
	_machine(mode).close_overlay()
	mode.confirm()
	assert_int(mode.rumours_added).is_equal(1)
	assert_int(mode.lines_said.size()).is_equal(2)


func test_a_recruit_remark_is_optional() -> void:
	for remark: String in ["", "remark_fixture_rookie"]:
		var map: OverworldMap = auto_free((load(ProbeFixture.SEGMENT) as PackedScene).instantiate())
		var gag: GagInteractable = ProbeFixture.gag(_AHEAD, GagInteractable.Response.CHANGE)
		gag.recruit_remark = remark
		map.add_child(gag)
		var catalog := RecordCatalogDouble.new()
		catalog.add(&"map", load("res://data/maps/%s.tres" % _SEGMENT_ID))
		for f: String in DirAccess.get_files_at("res://data/encounters"):
			if f.ends_with(".tres"):
				catalog.add(&"encounter", load("res://data/encounters/" + f))
		var errors: PackedStringArray = MapValidator.check_references({_SEGMENT_ID: map}, catalog,
				load("res://data/chapters/chapter_paris_flags.tres") as StoryFlagRegistry)
		assert_array(Array(errors)).override_failure_message("remark '%s': %s" % [remark, errors]).is_empty()


func _facing(gag: GagInteractable) -> OverworldMode:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([gag]))
	ProbeFixture.stand(mode, _AT, Vector2.UP)
	return mode


func _machine(mode: OverworldMode) -> GameStateMachine:
	return mode.get("_machine")


func _through_json(d: Dictionary) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d))
	parsed["party_pos"] = Vector2(parsed["party_pos"][0], parsed["party_pos"][1])
	parsed["party_facing"] = Vector2(parsed["party_facing"][0], parsed["party_facing"][1])
	return parsed
