## Story 047, AC-20a: grace starts on `transition_finished`, never in
## `on_thawed`, after Victory, Fled, a map load and a redirect alike; an
## overlapping eligible symbol starts no encounter at `encounter_grace_s -
## dt` and does at `encounter_grace_s + dt` (GDD rule 7 step 2).
extends GdUnitTestSuite

const _WON: String = "enc_fixture_won"
const _NEAR: String = "enc_fixture_near"
const _DT: float = 0.05
const _LEADER: Vector2 = Vector2(3.5, 5.5)

enum Trigger { VICTORY, FLED, MAP_LOAD, REDIRECT }


func test_grace_after_victory() -> void:
	_assert_case(OverworldConfig.new(), Trigger.VICTORY)


func test_grace_after_fled() -> void:
	_assert_case(OverworldConfig.new(), Trigger.FLED)


func test_grace_after_map_load() -> void:
	_assert_case(OverworldConfig.new(), Trigger.MAP_LOAD)


func test_grace_after_redirect() -> void:
	_assert_case(OverworldConfig.new(), Trigger.REDIRECT)


func test_grace_custom_config_every_trigger() -> void:
	var cfg := OverworldConfig.new()
	cfg.encounter_grace_s = 1.5
	for t: int in [Trigger.VICTORY, Trigger.FLED, Trigger.MAP_LOAD, Trigger.REDIRECT]:
		_assert_case(cfg, t)


func _assert_case(cfg: OverworldConfig, trigger: int) -> void:
	var spy := RequestSpyMachine.new()
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(spy, cfg, _LEADER, [_WON, _NEAR]))
	# The battle's own symbol, far away.
	var won: EncounterSource = mode.add_symbol(_WON,
			SymbolBrain.new(PackedVector2Array([Vector2(9.5, 2.5)]), SymbolBrain.PathMode.LOOP))
	var requests_before: int = 0
	if trigger == Trigger.VICTORY or trigger == Trigger.FLED:
		mode.start_encounter(_WON, won)
		requests_before = 1
		mode.on_thawed(_WON, GameStateMachine.BattleResult.VICTORY if trigger == Trigger.VICTORY
				else GameStateMachine.BattleResult.FLED)
		assert_bool(mode.grace_active).override_failure_message("grace started in on_thawed").is_false()
	elif trigger == Trigger.REDIRECT:
		spy.transition_started.emit(GameStateMachine.Mode.OVERWORLD, GameStateMachine.Mode.OVERWORLD)
	# An eligible Patrol symbol overlapping the leader for the whole window.
	mode.add_symbol(_NEAR, SymbolBrain.new(PackedVector2Array([_LEADER]), SymbolBrain.PathMode.LOOP, 1))
	assert_int(mode.grace_starts).is_equal(0)
	spy.transition_finished.emit(GameStateMachine.Mode.OVERWORLD)
	assert_int(mode.grace_starts).is_equal(1)
	assert_float(mode.get_grace_left()).is_equal(cfg.encounter_grace_s)
	mode.step_frame(cfg.encounter_grace_s - _DT, Vector2.ZERO)
	assert_int(spy.payloads.size()).override_failure_message(
			"encounter inside grace (trigger %d)" % trigger).is_equal(requests_before)
	mode.step_frame(2.0 * _DT, Vector2.ZERO)
	assert_int(spy.payloads.size()).override_failure_message(
			"no encounter after grace (trigger %d)" % trigger).is_equal(requests_before + 1)
	assert_array(spy.encounter_ids().slice(requests_before)).is_equal([_NEAR])
