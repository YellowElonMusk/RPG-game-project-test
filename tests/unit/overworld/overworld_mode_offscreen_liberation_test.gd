## Story 052, AC-21d (GDD rules 9, 7a; ADR-0012 §5): a Victory whose linked
## clutter marker is outside the camera footprint liberates it in
## `on_thawed` (liberated set, cells freed), and on `transition_finished`
## the off-screen sting and the payoff card's "Street cleared" line arrive
## on the same frame. The on-screen contrast fixture guards against the two
## paths merging: it stays shown until the reveal, plays the on-screen
## removal cue (never the sting) and is gone within `liberation_duration_s`.
extends GdUnitTestSuite

const _CLERK: String = "enc_paris_clerks_east"
const _MARKER: StringName = &"queue_fixture"
const _STREET: String = "Rue des Fixtures 052"
const _QUEUE_AT: Vector2 = Vector2(13.0, 14.5)
const _FAR_LEADER: Vector2 = Vector2(1.5, 1.5)
const _NEAR_OFFSET: Vector2 = Vector2(-2.0, 0.0)
const _DT: float = 1.0 / 60.0


## Records each cue together with the payoff card as it stood at emit time,
## so "same frame" means the card line was already up when the sting fired.
class CueSpy:
	extends RefCounted
	var mode: OverworldMode
	var cues: Array[Dictionary] = []

	func _init(p_mode: OverworldMode) -> void:
		mode = p_mode

	func on_cue(event: StringName, subject: String) -> void:
		cues.append({"event": event, "subject": subject,
				"card": mode.payoff_card_text, "phase": mode.payoff_card_phase})

	## The cues of `event` about this story's fixture marker (the segment's
	## own clutter may share the Clerk's link and cue alongside it).
	func of(event: StringName) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for c: Dictionary in cues:
			if c["event"] == event and c["subject"] == String(_MARKER):
				out.append(c)
		return out


func test_off_screen_victory_is_liberated_in_on_thawed() -> void:
	var mode: OverworldMode = _mode(_FAR_LEADER)
	var cell: Vector2i = mode.get_walk_grid().cell_of(_QUEUE_AT)
	assert_bool(mode.get_walk_grid().is_walkable(cell)).is_false()
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	assert_bool(mode.world_state.is_liberated(mode.get_map().map_id, _MARKER)).is_true()
	assert_bool(mode.get_walk_grid().is_walkable(cell)).is_true()
	assert_bool(_shown(mode)).is_false()
	assert_bool(mode.is_removing(_queue(mode))).is_false()


func test_off_screen_sting_and_street_cleared_line_share_the_reveal_frame() -> void:
	var mode: OverworldMode = _mode(_FAR_LEADER)
	var spy := CueSpy.new(mode)
	mode.sfx_cue.connect(spy.on_cue)
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	# Nothing heard or seen under the wipe.
	assert_array(spy.of(OverworldSfx.LIBERATION_OFF_SCREEN)).is_empty()
	assert_str(mode.payoff_card_text).is_empty()
	_reveal(mode)
	var stings: Array[Dictionary] = spy.of(OverworldSfx.LIBERATION_OFF_SCREEN)
	assert_int(stings.size()).is_equal(1)
	assert_str(String(stings[0]["subject"])).is_equal(String(_MARKER))
	# The card line was already up when the sting fired: the same frame.
	assert_str(String(stings[0]["card"])).contains("Street cleared: %s" % _STREET)
	assert_int(int(stings[0]["phase"])).is_equal(OverworldMode.CardPhase.SHOWN)
	assert_str(mode.payoff_card_text).contains("Street cleared: %s" % _STREET)
	# The off-screen path never plays the on-screen removal.
	assert_array(spy.of(OverworldSfx.LIBERATION)).is_empty()


func test_off_screen_marker_never_liberates_silently() -> void:
	# A marker with no street label still gets a card line (its id).
	var mode: OverworldMode = _mode(_FAR_LEADER, "")
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	_reveal(mode)
	assert_str(mode.payoff_card_text).contains("Street cleared: %s" % String(_MARKER))


func test_on_screen_contrast_plays_its_removal_not_the_sting() -> void:
	_assert_on_screen_contrast(OverworldConfig.new().liberation_duration_s)


func test_on_screen_contrast_non_default_duration() -> void:
	_assert_on_screen_contrast(OverworldConfig.new().liberation_duration_s * 2.5)


func _assert_on_screen_contrast(duration: float) -> void:
	var mode: OverworldMode = _mode(_QUEUE_AT + _NEAR_OFFSET)
	mode.config.liberation_duration_s = duration
	var spy := CueSpy.new(mode)
	mode.sfx_cue.connect(spy.on_cue)
	var cell: Vector2i = mode.get_walk_grid().cell_of(_QUEUE_AT)
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	assert_bool(mode.world_state.is_liberated(mode.get_map().map_id, _MARKER)).is_true()
	# Visible and blocking until the reveal; no cue yet.
	assert_bool(_shown(mode)).is_true()
	assert_bool(mode.get_walk_grid().is_walkable(cell)).is_false()
	assert_array(spy.of(OverworldSfx.LIBERATION)).is_empty()
	_reveal(mode)
	assert_int(spy.of(OverworldSfx.LIBERATION).size()).is_equal(1)
	assert_array(spy.of(OverworldSfx.LIBERATION_OFF_SCREEN)).is_empty()
	assert_str(mode.payoff_card_text).not_contains("Street cleared: %s" % _STREET)
	mode.tick_timed_text(duration - _DT)
	assert_bool(_shown(mode)).is_true()
	mode.tick_timed_text(2.0 * _DT)
	assert_bool(_shown(mode)).is_false()
	assert_bool(mode.get_walk_grid().is_walkable(cell)).is_true()


func _shown(mode: OverworldMode) -> bool:
	var box: Node3D = mode.get_map().get_node_or_null("PlaceholderSet/Gag_%s" % _MARKER) as Node3D
	assert_object(box).is_not_null()
	return box != null and box.visible


func _reveal(mode: OverworldMode) -> void:
	(mode.get("_machine") as GameStateMachine).transition_finished.emit(GameStateMachine.Mode.OVERWORLD)


func _queue(mode: OverworldMode) -> GagInteractable:
	for gag: GagInteractable in mode.get_map().gags():
		if gag.marker_id == _MARKER:
			return gag
	return null


func _mode(leader: Vector2, street: String = _STREET) -> OverworldMode:
	var queue := GagInteractable.new()
	queue.marker_id = _MARKER
	queue.text = "A queue."
	queue.liberate_symbol = _CLERK
	queue.blocked_rect = Rect2(_QUEUE_AT - Vector2(0.5, 0.5), Vector2.ONE)
	queue.street_label = street
	queue.position = Vector3(_QUEUE_AT.x, 0.0, _QUEUE_AT.y)
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([queue]))
	mode.set_leader_position(leader)
	return mode
