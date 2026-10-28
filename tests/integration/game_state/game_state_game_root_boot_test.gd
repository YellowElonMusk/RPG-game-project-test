## QA Test Cases 1-4 (game-state-scene-flow story 035): the real `GameRoot`
## main scene -- production `GameStateMachine`, `ModeHostSceneLoader`,
## `ChapterMode` and `BattleMode` -- so the production wiring is what is
## under test (same choice as `game_state_battle_mode_test.gd`, story 034).
## Written to the QA Test Cases in
## production/epics/game-state-scene-flow/story-035-game-root-main-scene.md
## -- no new cases invented.
##
## Check 2 runs in its own subprocess (`boot_content_error_harness.gd`):
## `ContentCatalog` is a one-shot autoload, so a `FAILED`-root scenario
## cannot share a process with Checks 1/3/4, which all boot the same valid
## fixture and rely on the catalog settling at `READY` once, however many
## `GameRoot` instances this file builds.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _TRANSITION_CONFIG_PATH: String = "res://data/config/transition_config.tres"
## The real data root: the demo loop needs the shipped Bureaucratia records,
## and ContentCatalog loads once per process, so every test here shares it.
const _VALID_FIXTURE: String = "res://data"
const _FAILED_FIXTURE: String = "res://tests/unit/content_data/fixtures/one_error_rest_valid"
const _HARNESS_SCRIPT: String = "res://tests/integration/game_state/boot_content_error_harness.gd"


func test_boots_to_title_on_valid_root() -> void:
	var game_root: GameRoot = _boot_game_root(_VALID_FIXTURE)
	var machine: GameStateMachine = game_root.machine

	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.TITLE)

	# The real transition_config.tres, loaded fresh from disk, passes
	# validate() with zero errors (the config GameRoot itself loaded is
	# already proof of this; this is the Check's own independent load).
	var config: TransitionConfig = ResourceLoader.load(_TRANSITION_CONFIG_PATH) as TransitionConfig
	assert_object(config).is_not_null()
	assert_bool(config.validate(SpyGameStateLog.new())).is_true()

	# The machine's action source is this GameRoot's own InputResolver
	# instance: feeding a bound key through it (Enter -> confirm,
	# bindings_default) must reach TitleMode's focused New Game button and
	# start the Title -> Overworld transition. A disconnected resolver
	# instance would leave the machine untouched.
	var enter_event := InputEventKey.new()
	enter_event.physical_keycode = KEY_ENTER
	enter_event.pressed = true
	game_root.resolver.feed_event(enter_event)
	assert_int(machine.phase).override_failure_message(
			"ENTER through GameRoot's own resolver did not reach the machine" \
			+ " -- the bound action source is not this resolver instance").is_not_equal(
			GameStateMachine.Phase.IDLE)
	_run_to_idle(machine)
	# With the real data root, ChapterMode (the Overworld stand-in) starts
	# fight 0 as soon as it is entered, so the loop settles in BATTLE; what
	# this check pins is that New Game left Title through this resolver.
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)


func test_boots_to_content_error_on_failed_root() -> void:
	var result: Dictionary = _run_subprocess(_FAILED_FIXTURE)
	var output: String = result["output"]
	assert_int(result["exit_code"]).override_failure_message("output:\n%s" % output).is_equal(0)
	assert_str(output).contains("MODE=%d" % GameStateMachine.Mode.CONTENT_ERROR)
	assert_str(output).contains("FALLBACK=true")

	# The on-screen text matches ValidationReportText.build_error_screen_text()
	# over the same fixture's report, built from a throwaway (non-autoload)
	# catalog instance -- the documented way to load a fixture root outside
	# production boot.
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	ContentBootstrap.run(catalog, _FAILED_FIXTURE)
	var expected_text: String = ValidationReportText.build_error_screen_text(
			catalog.report, 20, ContentErrorMode.LOG_PATH)
	var shown_text: String = _extract_between(output, "TEXT_START\n", "\nTEXT_END")
	assert_str(shown_text).is_equal(expected_text)

	# The log file was written (shared user:// data dir between this process
	# and the subprocess).
	assert_bool(FileAccess.file_exists(ContentErrorMode.LOG_PATH)).is_true()


func test_demo_loop_scripted() -> void:
	var game_root: GameRoot = _boot_game_root(_VALID_FIXTURE)
	var machine: GameStateMachine = game_root.machine

	assert_int(machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)

	# Fight 0: scripted DEFEAT -> Retry -> VICTORY, mid-chapter (QA Check 3).
	var battle_mode: BattleMode = game_root.current_mode_node() as BattleMode
	assert_object(battle_mode).is_not_null()
	DebugLaunchArgs.force_outcome(battle_mode.battle, DebugLaunchArgs.DEFEAT)
	assert_int(machine.overlay_stack.back()).is_equal(GameStateMachine.OverlayKind.DEFEAT_PROMPT)
	assert_int(machine.choose_retry()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
	assert_bool(is_same(game_root.current_mode_node(), battle_mode)).override_failure_message(
			"Retry rebuilt the BattleMode node instead of reusing it").is_true()
	DebugLaunchArgs.force_outcome(battle_mode.battle, DebugLaunchArgs.VICTORY)
	assert_int(machine.report_results_done()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	# Fights 1-3 (fight 3 is the boss): straight VICTORY each -- four
	# scripted fights total, ending the chapter.
	for fight_index: int in range(3):
		assert_int(machine.current_mode).override_failure_message(
				"expected BATTLE at fight index %d" % (fight_index + 1)).is_equal(
				GameStateMachine.Mode.BATTLE)
		battle_mode = game_root.current_mode_node() as BattleMode
		assert_object(battle_mode).is_not_null()
		DebugLaunchArgs.force_outcome(battle_mode.battle, DebugLaunchArgs.VICTORY)
		assert_int(machine.report_results_done()).is_equal(GameStateMachine.RequestResult.OK)
		_run_to_idle(machine)

	assert_int(machine.current_mode).override_failure_message(
			"chapter_won did not stop ChapterMode from requesting a fifth fight").is_equal(
			GameStateMachine.Mode.OVERWORLD)
	var chapter_mode: ChapterMode = game_root.current_mode_node() as ChapterMode
	assert_object(chapter_mode).is_not_null()
	assert_bool(chapter_mode.chapter.chapter_complete).override_failure_message(
			"chapter_won was never reached").is_true()


func test_quit_mid_battle_no_orphans() -> void:
	var game_root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	game_root.data_root_override = _VALID_FIXTURE
	add_child(game_root)
	var machine: GameStateMachine = game_root.machine
	_run_to_idle(machine)
	machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)

	# E8 (manifest advisory): freeing GameRoot mid-battle -- with a detached,
	# frozen Overworld (ChapterMode) held only by the loader -- must not
	# orphan it. No auto_free(): queue_free() is the point under test, and
	# gdUnit4's own orphan scan at teardown is what proves it worked (exit
	# 101 on a leak).
	game_root.queue_free()
	await get_tree().process_frame


## Boots a fresh GameRoot against `data_root`, drives it to an idle mode
## outside BOOT, and registers it for teardown.
func _boot_game_root(data_root: String) -> GameRoot:
	var game_root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	game_root.data_root_override = data_root
	add_child(game_root)
	auto_free(game_root)
	_run_to_idle(game_root.machine)
	return game_root


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()


## Runs `boot_content_error_harness.gd` as a real child process (the settled
## harness pattern, per `content_data_validate_cli_test.gd`).
func _run_subprocess(data_root: String) -> Dictionary:
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", _HARNESS_SCRIPT, "--", "--data-root=%s" % data_root,
	], output, true)
	# Normalised: on Windows the child prints CRLF, and the markers are LF.
	return {"exit_code": exit_code, "output": "\n".join(output).replace("\r\n", "\n")}


func _extract_between(text: String, start_marker: String, end_marker: String) -> String:
	var start: int = text.find(start_marker) + start_marker.length()
	var end: int = text.find(end_marker, start)
	return text.substr(start, end - start)
