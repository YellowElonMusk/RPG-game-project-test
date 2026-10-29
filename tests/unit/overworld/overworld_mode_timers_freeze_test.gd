## Story 048, AC-20b: grace, notice, give-up, cooldown and stun timers do not
## advance while the Menu, Dialogue or CampPrompt is open, or while a
## transition runs, and resume exactly where they were (ADR-0012 §2 one
## clock; GDD States: "advance only in Exploring").
##
## A transition's end is `transition_finished`, which by GDD rule 7 restarts
## grace and switches Noticing/Chasing to Returning; for those three timers
## the transition case asserts the freeze and then that rule-7 outcome.
extends GdUnitTestSuite

const _ENC: String = "enc_fixture_clerk"
const _DT: float = 0.05
const _SUSPENDED_FRAMES: int = 3

enum TimerKind { GRACE, NOTICE, GIVEUP, COOLDOWN, STUN }
enum Suspend { MENU, DIALOGUE, CAMP_PROMPT, TRANSITION }


func test_timer_freezes_under_suspension(timer: int, suspend: int, test_parameters := [
		[TimerKind.GRACE, Suspend.MENU], [TimerKind.GRACE, Suspend.DIALOGUE],
		[TimerKind.GRACE, Suspend.CAMP_PROMPT], [TimerKind.GRACE, Suspend.TRANSITION],
		[TimerKind.NOTICE, Suspend.MENU], [TimerKind.NOTICE, Suspend.DIALOGUE],
		[TimerKind.NOTICE, Suspend.CAMP_PROMPT], [TimerKind.NOTICE, Suspend.TRANSITION],
		[TimerKind.GIVEUP, Suspend.MENU], [TimerKind.GIVEUP, Suspend.DIALOGUE],
		[TimerKind.GIVEUP, Suspend.CAMP_PROMPT], [TimerKind.GIVEUP, Suspend.TRANSITION],
		[TimerKind.COOLDOWN, Suspend.MENU], [TimerKind.COOLDOWN, Suspend.DIALOGUE],
		[TimerKind.COOLDOWN, Suspend.CAMP_PROMPT], [TimerKind.COOLDOWN, Suspend.TRANSITION],
		[TimerKind.STUN, Suspend.MENU], [TimerKind.STUN, Suspend.DIALOGUE],
		[TimerKind.STUN, Suspend.CAMP_PROMPT], [TimerKind.STUN, Suspend.TRANSITION]]) -> void:
	var cfg := OverworldConfig.new()
	var spy := RequestSpyMachine.new()
	var sym := Vector2(4.5, 5.5)
	var leader: Vector2 = sym + Vector2(1.0, 0.0)
	if timer == TimerKind.COOLDOWN or timer == TimerKind.STUN or timer == TimerKind.GRACE:
		leader = Vector2(10.5, 8.5)  # Far: no notice, no contact.
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(spy, cfg, leader, [_ENC]))
	var b := SymbolBrain.new(PackedVector2Array([sym]), SymbolBrain.PathMode.LOOP)
	mode.add_symbol(_ENC, b)
	var read: Callable
	match timer:
		TimerKind.GRACE:
			b.rejoin_patrol(cfg)
			spy.transition_finished.emit(GameStateMachine.Mode.OVERWORLD)
			read = mode.get_grace_left
		TimerKind.NOTICE:
			mode.step_frame(_DT, Vector2.ZERO)  # Notice test passes -> Noticing.
			assert_int(b.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
			read = b.notice_elapsed
		TimerKind.GIVEUP:
			mode.step_frame(_DT, Vector2.ZERO)
			mode.step_frame(cfg.notice_delay_s, Vector2.ZERO)
			assert_int(b.sub_state).is_equal(SymbolBrain.SubState.CHASING)
			mode.set_leader_position(Vector2(11.5, 0.5))  # Beyond symbol_giveup_m.
			mode.step_frame(_DT, Vector2.ZERO)
			mode.step_frame(_DT, Vector2.ZERO)
			read = b.giveup_elapsed
		TimerKind.COOLDOWN:
			b.rejoin_patrol(cfg)
			read = b.cooldown_left
		TimerKind.STUN:
			b.on_fled(leader, Vector2.ZERO, mode.get_walk_grid(), cfg)
			read = b.stun_left
	var before: float = read.call()
	var state_before: int = b.sub_state
	_suspend(mode, spy, suspend, true)
	assert_bool(mode.is_exploring()).is_false()
	for i in _SUSPENDED_FRAMES:
		mode.step_frame(_DT, Vector2.ZERO)
	assert_float(read.call()).override_failure_message("timer moved while suspended").is_equal(before)
	assert_int(b.sub_state).is_equal(state_before)
	_suspend(mode, spy, suspend, false)
	assert_bool(mode.is_exploring()).is_true()
	if suspend == Suspend.TRANSITION and timer == TimerKind.GRACE:
		assert_float(read.call()).is_equal(cfg.encounter_grace_s)  # Rule 7 restart.
		return
	if suspend == Suspend.TRANSITION and (timer == TimerKind.NOTICE or timer == TimerKind.GIVEUP):
		assert_int(b.sub_state).is_equal(SymbolBrain.SubState.RETURNING)  # Rule 7.
		return
	mode.step_frame(_DT, Vector2.ZERO)
	assert_float(absf(float(read.call()) - before)).is_equal_approx(_DT, 1e-6)


func _suspend(mode: OverworldMode, spy: RequestSpyMachine, kind: int, on: bool) -> void:
	match kind:
		Suspend.MENU:
			if on:
				spy.overlay_opened.emit(GameStateMachine.OverlayKind.MENU)
			else:
				spy.overlay_closed.emit(GameStateMachine.OverlayKind.MENU)
		Suspend.DIALOGUE:
			if on:
				spy.overlay_opened.emit(GameStateMachine.OverlayKind.DIALOGUE)
			else:
				spy.overlay_closed.emit(GameStateMachine.OverlayKind.DIALOGUE)
		Suspend.CAMP_PROMPT:
			mode.set_camp_prompt_open(on)
		Suspend.TRANSITION:
			if on:
				spy.transition_started.emit(GameStateMachine.Mode.OVERWORLD,
						GameStateMachine.Mode.OVERWORLD)
			else:
				spy.transition_finished.emit(GameStateMachine.Mode.OVERWORLD)
