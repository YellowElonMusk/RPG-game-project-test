## Story 016, AC-7f (GDD rule 3 Eligibility, rule 16): an open checkpoint
## and a `change` gag already changed drop out of `probe()` and draw no
## prompt; a `line` gag already used is still targeted and repeats (its
## alternate line); a `clue` gag used again adds no second rumour. Liberated
## markers do not exist yet (rule 9; TODO(overworld): stories 059-060).
extends GdUnitTestSuite

const _GAG_AT: Vector2 = Vector2(13.0, 14.5)  # 1 m east of ProbeFixture.OPEN_SPOT


func test_changed_gag_drops_out() -> void:
	var mode: OverworldMode = _mode(ProbeFixture.gag(_GAG_AT, GagInteractable.Response.CHANGE))
	mode.handle_action(InputActions.CONFIRM, true)
	assert_array(mode.lines_said).is_equal(["Fixture gag."])
	_close_line(mode)
	assert_object(mode.probe()).is_null()
	assert_str(String(mode.probe_kind())).is_empty()
	mode.handle_action(InputActions.CONFIRM, true)
	assert_int(mode.lines_said.size()).is_equal(1)


func test_used_line_gag_repeats_its_alternate() -> void:
	var mode: OverworldMode = _mode(ProbeFixture.gag(_GAG_AT, GagInteractable.Response.LINE))
	mode.handle_action(InputActions.CONFIRM, true)
	_close_line(mode)
	assert_object(mode.probe()).is_instanceof(GagInteractable)
	mode.handle_action(InputActions.CONFIRM, true)
	_close_line(mode)
	mode.handle_action(InputActions.CONFIRM, true)
	assert_array(mode.lines_said).is_equal(["Fixture gag.", "Fixture gag, again.", "Fixture gag, again."])


func test_clue_gag_adds_its_rumour_once() -> void:
	var mode: OverworldMode = _mode(ProbeFixture.gag(_GAG_AT, GagInteractable.Response.CLUE))
	mode.handle_action(InputActions.CONFIRM, true)
	_close_line(mode)
	mode.handle_action(InputActions.CONFIRM, true)
	assert_int(mode.rumours_added).is_equal(1)
	assert_bool(mode.has_rumour("rumour_fixture")).is_true()
	assert_int(mode.lines_said.size()).is_equal(2)


func test_open_checkpoint_drops_out() -> void:
	var cp := CheckpointMarker.new()
	cp.marker_id = &"cp_fixture"
	cp.requirement_flag = "fixture_flag"
	cp.blocked_rect = Rect2(13, 13, 1, 1)
	cp.position = Vector3(_GAG_AT.x, 0.0, _GAG_AT.y)
	var mode: OverworldMode = _mode(cp)
	assert_object(mode.probe()).is_instanceof(CheckpointMarker)
	mode.open_checkpoint(&"cp_fixture")
	assert_object(mode.probe()).is_null()


func test_shipped_clue_poster_adds_the_permit_rumour() -> void:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode())
	var poster: GagInteractable = mode.get_map().gags()[0]
	ProbeFixture.stand(mode, poster.ground_position(mode.get_map()) + Vector2(-1.0, 0.0), Vector2.RIGHT)
	mode.handle_action(InputActions.CONFIRM, true)
	assert_bool(mode.has_rumour("rumour_permit_ban")).is_true()
	assert_str(mode.lines_said[0]).contains("SPECIAL MOVES REQUIRE A PERMIT")


func _mode(marker: Node3D) -> OverworldMode:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([marker]))
	ProbeFixture.stand(mode, ProbeFixture.OPEN_SPOT, Vector2.RIGHT)
	return mode


func _close_line(mode: OverworldMode) -> void:
	# The fixture machine's loader shows no overlay; closing through Game
	# State is what the line's confirm does.
	var machine: GameStateMachine = mode.get("_machine")
	machine.close_overlay()
