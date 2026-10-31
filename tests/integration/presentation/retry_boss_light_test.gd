## Story 030 (GDD sprite-camera-presentation AC-26; ADR-0006 §5, ADR-0005
## §3/§4) with story 013's Battle-mode hooks (AC-11). In a boss fight run by
## the real Battle mode:
## - the first-encounter takeover requests `boss_<faction>` on
##   `hold_started(TAKEOVER_FULL)`, blending on the hold's own clock; while
##   the hold runs the stage reports a takeover and the hit-punch is wired
##   to it, so a punch is dropped;
## - Retry with an uncapped flash requests the boss end state at blend 0
##   during SWAP, after HP/MP restore and before the reveal gate; from the
##   first frame of IN every lighting value equals the boss preset; the
##   Director skips its entry apply on the Battle -> Battle row; the first
##   command menu waits `boss_retry_hold` after the gate opens;
## - with a capped flash the light moves from Defeat to the boss end state
##   as one smooth blend over `blend_defeat`;
## - an exit mid-takeover stops the takeover blend and the hold flag.
extends GdUnitTestSuite

const DT: float = BattleModeHarness.DT
const TOL: float = 1e-4
const BOSS_PROFILE: StringName = &"boss_bureaucratia"


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _profile(id: StringName) -> LightingProfile:
	return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile


## Every numeric/color field of `a` within TOL of `b`; returns the first
## mismatch, or "".
func _mismatch(a: LightingProfile, b: LightingProfile) -> String:
	for prop: Dictionary in b.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var key: StringName = StringName(prop["name"])
		var va: Variant = a.get(key)
		var vb: Variant = b.get(key)
		match typeof(vb):
			TYPE_FLOAT:
				if absf(float(va) - float(vb)) > TOL:
					return "%s: %s vs %s" % [key, va, vb]
			TYPE_COLOR:
				var ca: Color = va
				var cb: Color = vb
				if absf(ca.r - cb.r) > TOL or absf(ca.g - cb.g) > TOL or absf(ca.b - cb.b) > TOL:
					return "%s: %s vs %s" % [key, va, vb]
	return ""


func _boss_harness(flash_gate: FlashGatePort = null) -> BattleModeHarness:
	var h := BattleModeHarness.create(self, ChapterFlow.build_squad(BattleCatalog.shipped()), true,
			null, flash_gate)
	auto_free(h.mode)
	h.reveal()
	return h


func _play_until(h: BattleModeHarness, event_name: String, max_frames: int = 3000) -> void:
	var guard: int = 0
	while h.frames_of(event_name).is_empty() and guard < max_frames:
		h.step()
		guard += 1
	assert_array(h.frames_of(event_name)).is_not_empty()


## Plays the takeover, loses, plays the Defeat hold; leaves the prompt open.
func _lose(h: BattleModeHarness) -> void:
	var menu: BattleCommandMenu = h.mode.get_node(^"%BattleCommandMenu")
	var guard: int = 0
	while not menu.visible and guard < 3000:
		h.step()
		guard += 1
	DebugLaunchArgs.force_outcome(h.mode.battle, DebugLaunchArgs.DEFEAT)
	guard = 0
	while h.pending_outcome() == -1 and guard < 3000:
		h.step()
		guard += 1
	assert_int(h.pending_outcome()).is_equal(GameStateMachine.BattleResult.DEFEAT)


func test_takeover_requests_boss_light_on_hold_clock_and_drops_punches() -> void:
	var h := _boss_harness()
	_play_until(h, "hold_started")
	assert_bool(h.profile_requests.has(BOSS_PROFILE)).override_failure_message(
			"no boss light on hold_started(TAKEOVER_FULL)").is_true()
	assert_bool(h.stage.takeover_hold_active).is_true()
	assert_bool(h.stage.is_takeover_active()).is_true()
	var punch: HitPunch = h.mode.get(&"_hit_punch")
	assert_bool(punch.takeover_active.is_valid()).is_true()
	assert_bool(punch.on_impact(-10, false, false, Vector2.UP)).override_failure_message(
			"a punch during the takeover was not dropped").is_false()
	# The blend runs on the hold clock: complete after blend_boss of hold.
	var cfg: PresentationConfig = h.mode.presentation_config
	while h.mode.replay.get_hold_time() < cfg.blend_boss + DT and h.frames_of("hold_finished").is_empty():
		h.step()
	assert_str(_mismatch(h.stage.current_values, _profile(BOSS_PROFILE))).is_empty()
	_play_until(h, "hold_finished")
	assert_bool(h.stage.takeover_hold_active).is_false()
	assert_bool(h.stage.is_takeover_active()).is_false()


func test_uncapped_retry_shows_boss_end_state_and_settles() -> void:
	var h := _boss_harness()
	var director := PresentationDirector.new()
	add_child(director)
	auto_free(director)
	director.setup(h.machine, PresentationConfig.new(), GlobalUniformSink.new())
	_lose(h)
	var log_mark: int = h.profile_log.size()
	assert_int(h.machine.choose_retry()).is_equal(GameStateMachine.RequestResult.OK)
	var boss: LightingProfile = _profile(BOSS_PROFILE)
	var gate_frame: int = -1
	var ticks: int = 0
	while h.machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		h.machine.tick(DT)
		h.step()
		ticks += 1
		if h.machine.phase == GameStateMachine.Phase.IN or h.machine.phase == GameStateMachine.Phase.IDLE:
			assert_str(_mismatch(h.stage.current_values, boss)).override_failure_message(
					"retry light off the boss end state during IN").is_empty()
	gate_frame = h.frame
	# The spy: the boss light was requested in SWAP, after the restore and
	# before the reveal gate (the replay still IDLE).
	var req: Dictionary = {}
	for i: int in range(log_mark, h.profile_log.size()):
		if h.profile_log[i]["id"] == BOSS_PROFILE:
			req = h.profile_log[i]
			break
	assert_bool(req.is_empty()).override_failure_message("no boss light requested on Retry").is_false()
	assert_int(int(req["phase"])).is_equal(GameStateMachine.Phase.SWAP)
	assert_int(int(req["replay_state"])).is_equal(BattleReplayController.State.IDLE)
	for c: Combatant in h.mode.battle.squad:
		assert_int(c.hp).is_greater(0)
	# The Director skipped its entry apply on Battle -> Battle.
	assert_str(_mismatch(h.stage.current_values, boss)).is_empty()
	# The settle: the first menu waits boss_retry_hold after the gate opens.
	var turns_before: int = h.frames_of("turn").size()
	var guard: int = 0
	while h.frames_of("turn").size() == turns_before and guard < 600:
		h.step()
		guard += 1
	var waited: float = float(h.frames_of("turn")[-1] - gate_frame) * DT
	assert_float(absf(waited - h.mode.presentation_config.boss_retry_hold)).is_less_equal(DT + 1e-6)
	assert_str(_mismatch(h.stage.current_values, boss)).is_empty()


func test_capped_retry_blends_defeat_to_boss_over_blend_defeat() -> void:
	var gate := StubFlashGate.new()
	var h := _boss_harness(gate)
	_lose(h)
	gate.capped_result = true
	assert_int(h.machine.choose_retry()).is_equal(GameStateMachine.RequestResult.OK)
	assert_bool(h.machine.is_transition_flash_capped()).is_true()
	var cfg: PresentationConfig = h.mode.presentation_config
	var series: Array[float] = []
	var ticks: int = 0
	while ticks < 600 and (h.machine.phase != GameStateMachine.Phase.IDLE or h.stage.is_blending()):
		h.machine.tick(DT)
		h.step()
		series.append(h.stage.current_values.key_energy if h.stage.current_values != null else 0.0)
		ticks += 1
	assert_str(_mismatch(h.stage.current_values, _profile(BOSS_PROFILE))).is_empty()
	var defeat_key: float = _profile(&"defeat").key_energy
	var boss_key: float = _profile(BOSS_PROFILE).key_energy
	var span: float = absf(boss_key - defeat_key)
	# smoothstep's steepest slope is 1.5: one frame moves at most
	# 1.5 * DT / blend_defeat of the span.
	var max_step: float = 1.5 * DT / cfg.blend_defeat * span + TOL
	for i: int in range(1, series.size()):
		assert_float(absf(series[i] - series[i - 1])).is_less_equal(max_step)
	if span > TOL:
		var moving: int = 0
		for i: int in range(1, series.size()):
			if absf(series[i] - series[i - 1]) > 1e-7:
				moving += 1
		assert_int(moving).override_failure_message("capped retry popped instead of blending").is_greater(2)


func test_exit_mid_takeover_stops_takeover_blend_and_hold_flag() -> void:
	var h := _boss_harness()
	_play_until(h, "hold_started")
	h.step(5)
	assert_bool(h.stage.is_takeover_active()).is_true()
	h.machine.open_overlay(GameStateMachine.OverlayKind.MENU, MenuPayload.new())
	assert_int(h.machine.request_transition(GameStateMachine.Mode.TITLE)).is_equal(
			GameStateMachine.RequestResult.OK)
	assert_bool(h.stage.takeover_hold_active).is_false()
	assert_bool(h.stage.is_takeover_active()).is_false()
	var frozen: LightingProfile = h.stage.current_values
	h.step(30)
	assert_str(_mismatch(h.stage.current_values, frozen)).is_empty()
