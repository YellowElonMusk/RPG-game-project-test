## Story 126, AC-53 (GDD Visual/Audio Requirements § Audio direction, [A11Y]):
## for every overworld SFX event in the audio table, an event spy records the
## sound (`OverworldMode.sfx_cue`) on the same frame its visual twin first
## shows. The off-screen liberation sting's twin is the payoff card's
## "Street cleared" line. Visual twins are read from the model state the
## presentation draws (sub-state poses, removal, card, Dialogue line), and
## `pending_thaw` is the "scene still under the wipe" flag (ADR-0002 / 0012 §5).
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _ENC: String = "enc_fixture_twin"
const _CLERK: String = "enc_paris_clerks_east"
const _QUEUE_AT: Vector2 = Vector2(13.0, 14.5)
const _LEADER: Vector2 = Vector2(3.5, 5.5)
const _NOTICER_AT: Vector2 = Vector2(1.5, 7.0)
const _CP: StringName = &"cp_fixture_twin"
const _DT: float = 1.0 / 60.0
const _MAX_FRAMES: int = 600


## Event spy: records each cue with the frame it fired on and whether its
## twin was showing at that moment; `end_frame()` samples the twin once per
## frame to find the first frame it shows.
class TwinSpy:
	extends RefCounted
	var frame: int = 0
	var cues: Array[Dictionary] = []
	var twin_frame: int = -1
	var _twin: Callable

	func _init(twin: Callable) -> void:
		_twin = twin

	func on_cue(event: StringName, subject: String) -> void:
		cues.append({"event": event, "subject": subject, "frame": frame, "twin": bool(_twin.call())})

	func end_frame() -> void:
		if twin_frame < 0 and bool(_twin.call()):
			twin_frame = frame
		frame += 1

	func of(event: StringName) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for c: Dictionary in cues:
			if c["event"] == event:
				out.append(c)
		return out


func test_audio_table_has_six_rows() -> void:
	assert_array(OverworldSfx.ALL).is_equal([OverworldSfx.NOTICE, OverworldSfx.CHASE,
			OverworldSfx.STUN, OverworldSfx.LIBERATION, OverworldSfx.LIBERATION_OFF_SCREEN,
			OverworldSfx.CHECKPOINT_DENIED])


func test_notice_sounds_with_the_notice_pose() -> void:
	var mode: OverworldMode = _symbol_mode(OverworldConfig.new())
	var brain: SymbolBrain = mode.get_symbol_brains()[0]
	var spy := _spy(mode, func() -> bool: return brain.sub_state == SymbolBrain.SubState.NOTICING)
	_step_until(mode, spy, func() -> bool: return brain.sub_state == SymbolBrain.SubState.NOTICING)
	_assert_twinned(spy, OverworldSfx.NOTICE, _ENC)


func test_chase_sounds_with_the_chase_pose() -> void:
	_run_chase(OverworldConfig.new())


func test_chase_sounds_with_the_chase_pose_non_default_notice_delay() -> void:
	var cfg := OverworldConfig.new()
	cfg.notice_delay_s *= 2.0
	_run_chase(cfg)


func test_stun_sounds_with_the_orbiting_slips_on_the_reveal() -> void:
	var mode: OverworldMode = _symbol_mode(OverworldConfig.new())
	var brain: SymbolBrain = mode.get_symbol_brains()[0]
	var spy := _spy(mode, func() -> bool:
		return not mode.pending_thaw and brain.sub_state == SymbolBrain.SubState.STUNNED)
	spy.end_frame()
	mode.on_thawed(_ENC, GameStateMachine.BattleResult.FLED)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.STUNNED)
	spy.end_frame()  # under the wipe: no slips seen, no sound
	assert_array(spy.of(OverworldSfx.STUN)).is_empty()
	_reveal(mode)
	spy.end_frame()
	_assert_twinned(spy, OverworldSfx.STUN, _ENC)


func test_on_screen_liberation_sounds_with_the_clutter_removal() -> void:
	var mode: OverworldMode = _clutter_mode(_QUEUE_AT + Vector2(-2.0, 0.0))
	var queue: GagInteractable = _queue(mode)
	var spy := _spy(mode, func() -> bool: return not mode.pending_thaw and mode.is_removing(queue))
	spy.end_frame()
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	spy.end_frame()
	_reveal(mode)
	spy.end_frame()
	_assert_twinned(spy, OverworldSfx.LIBERATION, "queue_fixture")
	# The on-screen queue gets no sting (the segment's off-screen markers may).
	for c: Dictionary in spy.of(OverworldSfx.LIBERATION_OFF_SCREEN):
		assert_str(String(c["subject"])).is_not_equal("queue_fixture")


func test_off_screen_sting_sounds_with_the_street_cleared_card_line() -> void:
	var mode: OverworldMode = _clutter_mode(Vector2(1.5, 1.5))
	var spy := _spy(mode, func() -> bool:
		return mode.payoff_card_phase == OverworldMode.CardPhase.SHOWN \
				and mode.payoff_card_text.contains("Street cleared: Rue des Fixtures"))
	spy.end_frame()
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	spy.end_frame()  # removed already, but the card waits for the reveal
	assert_array(spy.of(OverworldSfx.LIBERATION_OFF_SCREEN)).is_empty()
	_reveal(mode)
	spy.end_frame()
	_assert_twinned(spy, OverworldSfx.LIBERATION_OFF_SCREEN, "queue_fixture")
	assert_array(spy.of(OverworldSfx.LIBERATION)).is_empty()


func test_checkpoint_denial_sounds_with_the_denied_line() -> void:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode: OverworldMode = _checkpoint_mode(machine, "DENIED. Form 27-B, please.")
	var spy := _spy(mode, func() -> bool:
		return machine.overlay_stack.has(GameStateMachine.OverlayKind.DIALOGUE) \
				and not mode.lines_said.is_empty() and mode.lines_said.back() == "DENIED. Form 27-B, please.")
	spy.end_frame()
	mode.confirm_checkpoint(_CP)
	spy.end_frame()
	_assert_twinned(spy, OverworldSfx.CHECKPOINT_DENIED, String(_CP))


func test_met_requirement_opens_without_a_denial_cue() -> void:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode: OverworldMode = _checkpoint_mode(machine, "DENIED.")
	var spy := _spy(mode, func() -> bool: return false)
	mode.open_checkpoint(_CP)
	mode.confirm_checkpoint(_CP)
	assert_array(spy.cues).is_empty()


# -- helpers -----------------------------------------------------------------

func _run_chase(cfg: OverworldConfig) -> void:
	var mode: OverworldMode = _symbol_mode(cfg)
	var brain: SymbolBrain = mode.get_symbol_brains()[0]
	var spy := _spy(mode, func() -> bool: return brain.sub_state == SymbolBrain.SubState.CHASING)
	_step_until(mode, spy, func() -> bool: return brain.sub_state == SymbolBrain.SubState.CHASING)
	_assert_twinned(spy, OverworldSfx.CHASE, _ENC)
	# The notice came first, on an earlier frame.
	var notice: Array[Dictionary] = spy.of(OverworldSfx.NOTICE)
	assert_int(notice.size()).is_equal(1)
	assert_int(int(notice[0]["frame"])).is_less(spy.twin_frame)


## Asserts exactly one `event` cue for `subject`, fired while its twin was
## showing and on the first frame the twin showed.
func _assert_twinned(spy: TwinSpy, event: StringName, subject: String) -> void:
	var cues: Array[Dictionary] = []
	for c: Dictionary in spy.of(event):
		if String(c["subject"]) == subject:
			cues.append(c)
	assert_int(cues.size()).is_equal(1)
	assert_bool(bool(cues[0]["twin"])).is_true()
	assert_int(spy.twin_frame).is_greater_equal(0)
	assert_int(int(cues[0]["frame"])).is_equal(spy.twin_frame)


func _spy(mode: OverworldMode, twin: Callable) -> TwinSpy:
	var spy := TwinSpy.new(twin)
	mode.sfx_cue.connect(spy.on_cue)
	return spy


func _step_until(mode: OverworldMode, spy: TwinSpy, done: Callable) -> void:
	while spy.frame < _MAX_FRAMES and not bool(done.call()):
		mode.step_frame(_DT, Vector2.ZERO)
		spy.end_frame()
	assert_bool(bool(done.call())).is_true()


func _reveal(mode: OverworldMode) -> void:
	(mode.get("_machine") as GameStateMachine).transition_finished.emit(GameStateMachine.Mode.OVERWORLD)


## A mode with one symbol close enough to notice the idle leader.
func _symbol_mode(cfg: OverworldConfig) -> OverworldMode:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(machine, cfg, _LEADER, [_ENC]))
	mode.world_state = WorldState.new()
	mode.add_symbol(_ENC, SymbolBrain.new(PackedVector2Array([_NOTICER_AT]), SymbolBrain.PathMode.LOOP, 0))
	mode.grace_active = false
	return mode


func _checkpoint_mode(machine: GameStateMachine, line: String) -> OverworldMode:
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(
			machine, OverworldConfig.new(), _LEADER, []))
	mode.world_state = WorldState.new()
	var cp: CheckpointMarker = auto_free(CheckpointMarker.new())
	cp.marker_id = _CP
	cp.requirement_item_id = "form_27b"
	cp.failure_outcome = CheckpointMarker.FailureOutcome.REDIRECT
	cp.failure_line = line
	cp.blocked_rect = Rect2(9, 4, 2, 1)
	cp.position = Vector3(9.5, 0.0, 5.3)
	cp.return_marker = Vector2(9.5, 7.5)
	cp.return_facing = Vector2.DOWN
	mode.add_checkpoint(cp)
	return mode


func _queue(mode: OverworldMode) -> GagInteractable:
	for gag: GagInteractable in mode.get_map().gags():
		if gag.marker_id == &"queue_fixture":
			return gag
	return null


## The segment with one queue the East Clerk liberates; the leader at `leader`.
func _clutter_mode(leader: Vector2) -> OverworldMode:
	var queue := GagInteractable.new()
	queue.marker_id = &"queue_fixture"
	queue.text = "A queue."
	queue.liberate_symbol = _CLERK
	queue.blocked_rect = Rect2(_QUEUE_AT - Vector2(0.5, 0.5), Vector2.ONE)
	queue.street_label = "Rue des Fixtures"
	queue.position = Vector3(_QUEUE_AT.x, 0.0, _QUEUE_AT.y)
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([queue]))
	mode.set_leader_position(leader)
	return mode
