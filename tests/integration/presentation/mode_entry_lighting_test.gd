## Story 008, AC-6: on `mode_entered`, `PresentationDirector` applies the
## entry profile at `blend_time = 0` while the transition still covers the
## screen (phase is still `SWAP`), skips the apply on a same-mode row
## (Retry), and never touches the rig again with no blend requested
## (ADR-0005 Decision §4). Drives the real `GameStateMachine` through
## `GameStateFixtures`, with a single `DioramaStage` standing in for
## whichever stage the real scene swap would have live -- the swap mechanics
## themselves are `SceneLoader`'s concern, already covered elsewhere.
extends GdUnitTestSuite

const _PROFILES_DIR: String = "res://data/presentation/profiles"
const _EPSILON: float = 1e-4

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")


func _build_stage(profile_id: StringName) -> DioramaStage:
	var stage: DioramaStage = auto_free(DioramaStage.new())
	stage.key_light = DirectionalLight3D.new()
	stage.set_light = DirectionalLight3D.new()
	stage.fill_light = DirectionalLight3D.new()
	stage.world_environment = WorldEnvironment.new()
	stage.world_environment.environment = Environment.new()
	stage.add_child(stage.key_light)
	stage.add_child(stage.set_light)
	stage.add_child(stage.fill_light)
	stage.add_child(stage.world_environment)
	stage.profile_id = profile_id
	return stage


func _load_profile(id: StringName) -> LightingProfile:
	var path: String = _PROFILES_DIR.path_join("%s.tres" % id)
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LightingProfile


func _assert_rig_matches(stage: DioramaStage, profile: LightingProfile, context: String) -> void:
	assert_bool(stage.key_light.light_color.is_equal_approx(profile.key_color)) \
			.override_failure_message("%s: key color mismatch" % context).is_true()
	assert_float(stage.key_light.light_energy).override_failure_message(
			"%s: key energy mismatch" % context).is_equal_approx(profile.key_energy, _EPSILON)
	assert_bool(stage.set_light.light_color.is_equal_approx(profile.set_color)) \
			.override_failure_message("%s: set color mismatch" % context).is_true()
	assert_float(stage.set_light.light_energy).override_failure_message(
			"%s: set energy mismatch" % context).is_equal_approx(profile.set_energy, _EPSILON)
	assert_bool(stage.fill_light.light_color.is_equal_approx(profile.fill_color)) \
			.override_failure_message("%s: fill color mismatch" % context).is_true()
	assert_float(stage.fill_light.light_energy).override_failure_message(
			"%s: fill energy mismatch" % context).is_equal_approx(profile.fill_energy, _EPSILON)
	assert_bool(stage.current_rim_color.is_equal_approx(profile.rim_color)) \
			.override_failure_message("%s: rim color mismatch" % context).is_true()
	assert_float(stage.current_rim_strength).override_failure_message(
			"%s: rim strength mismatch" % context).is_equal_approx(profile.rim_strength, _EPSILON)


func test_mode_entry_applies_entry_profile_before_reveal() -> void:
	var fixture: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = fixture["machine"]
	var cfg: TransitionConfig = fixture["config"]

	var stage: DioramaStage = _build_stage(&"battle")
	add_child(stage)

	var director: PresentationDirector = auto_free(PresentationDirector.new())
	add_child(director)
	director.setup(machine, PresentationConfig.new(), GlobalUniformSink.new())

	var phase_at_entry: Array = [GameStateMachine.Phase.IDLE]
	var entered: Array = [false]
	machine.mode_entered.connect(func(to: GameStateMachine.Mode) -> void:
		if to == GameStateMachine.Mode.BATTLE:
			phase_at_entry[0] = machine.phase
			entered[0] = true)

	var battle_profile: LightingProfile = _load_profile(&"battle")

	assert_int(machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())) \
			.is_equal(GameStateMachine.RequestResult.OK)
	machine.tick(cfg.t_out[&"battle_wipe"])
	# StubSceneLoader completes its swap on the first poll, so SWAP (and
	# mode_entered) resolves on this same next tick -- IN has not started yet.
	machine.tick(0.0)

	assert_bool(entered[0]).override_failure_message("mode_entered(BATTLE) never fired").is_true()
	assert_int(phase_at_entry[0]).override_failure_message(
			"PresentationDirector must apply the entry profile while phase is still SWAP," \
			+ " before the IN-phase reveal begins").is_equal(GameStateMachine.Phase.SWAP)
	_assert_rig_matches(stage, battle_profile, "on entry")

	# Over the next 120 frames, with no blend requested, nothing moves.
	for _frame: int in range(120):
		machine.tick(1.0 / 60.0)
	_assert_rig_matches(stage, battle_profile, "after 120 frames with no blend requested")


func test_retry_same_mode_row_skips_entry_profile_reapply() -> void:
	var fixture: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = fixture["machine"]
	var cfg: TransitionConfig = fixture["config"]

	var stage: DioramaStage = _build_stage(&"battle")
	add_child(stage)

	var director: PresentationDirector = auto_free(PresentationDirector.new())
	add_child(director)
	director.setup(machine, PresentationConfig.new(), GlobalUniformSink.new())

	machine.request_transition(GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	machine.tick(cfg.t_out[&"battle_wipe"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"battle_wipe"])
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)

	assert_int(machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	assert_int(machine.choose_retry()).is_equal(GameStateMachine.RequestResult.OK)

	# Simulates the owning Battle mode's own retry-light request, made during
	# the hidden SWAP before `mode_entered` fires (ADR-0005 §3) -- the stage's
	# resolver is already bound from the first entry above.
	var boss_profile: LightingProfile = _load_profile(&"boss_bureaucratia")
	stage.request_profile(&"boss_bureaucratia", 0.0)

	# retry_flash's OUT->SWAP->mode_entered->IN all resolve inside one tick
	# (GameStateMachine._end_retry_swap() has a zero-length SWAP).
	machine.tick(cfg.t_out[&"retry_flash"])

	_assert_rig_matches(stage, boss_profile, "retry: Director must not overwrite the retry light")


func test_no_active_stage_does_not_crash() -> void:
	var fixture: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = fixture["machine"]
	var cfg: TransitionConfig = fixture["config"]

	var director: PresentationDirector = auto_free(PresentationDirector.new())
	add_child(director)
	director.setup(machine, PresentationConfig.new(), GlobalUniformSink.new())

	# No DioramaStage anywhere in the tree (a 2D mode) -- must be a silent no-op.
	assert_int(machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())) \
			.is_equal(GameStateMachine.RequestResult.OK)
	machine.tick(cfg.t_out[&"battle_wipe"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"battle_wipe"])

	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
