## The Victory results screen (Stats & Damage GDD "Battle results", F9;
## Sprite & Camera rule 9's input guard and default focus).
extends GdUnitTestSuite


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _knocked_out(id: String) -> Combatant:
	var e: Combatant = BattleContentSeam.enemy(id)
	e.hp = 0
	return e


## F9's worked example: 3 Clerks + 1 Supervisor = 44 XP, 30 money (AC-30).
func test_rewards_sum_the_defeated_enemies_records() -> void:
	var foes: Array[Combatant] = [_knocked_out("enemy_clerk"), _knocked_out("enemy_clerk"),
			_knocked_out("enemy_clerk"), _knocked_out("enemy_supervisor")]
	var r: Dictionary = BattleRewards.totals(foes, BattleCatalog.shipped())
	assert_int(r["xp"]).is_equal(44)
	assert_int(r["money"]).is_equal(30)


## AC-30: an enemy removed without a knockout gives nothing.
func test_an_enemy_still_standing_gives_nothing() -> void:
	var foes: Array[Combatant] = [_knocked_out("enemy_clerk"), _knocked_out("enemy_clerk"),
			_knocked_out("enemy_clerk"), BattleContentSeam.enemy("enemy_supervisor")]
	var r: Dictionary = BattleRewards.totals(foes, BattleCatalog.shipped())
	assert_int(r["xp"]).is_equal(24)
	assert_int(r["money"]).is_equal(15)


func test_panel_opens_on_continue_and_guards_an_instant_confirm() -> void:
	var clock: Array[float] = [0.0]
	var panel: ResultsPanel = auto_free(ResultsPanel.new(func() -> float: return clock[0], 0.15))
	add_child(panel)
	var continued: Array[int] = [0]
	panel.continued.connect(func() -> void: continued[0] += 1)
	panel.show_results(44, 30)

	assert_str(panel.totals_text()).is_equal("+44 XP, +30 Money")
	assert_object(panel.get_viewport().gui_get_focus_owner()).is_same(panel.continue_button())
	panel.handle_action(InputActions.CONFIRM, true)  # the same instant it opened
	assert_int(continued[0]).override_failure_message("a Confirm inside the guard continued").is_equal(0)
	clock[0] = 0.2
	panel.handle_action(InputActions.CONFIRM, true)
	panel.handle_action(InputActions.CONFIRM, true)
	assert_int(continued[0]).override_failure_message("Continue must fire exactly once").is_equal(1)


func test_battle_victory_shows_the_results_with_the_fights_rewards() -> void:
	var h := BattleModeHarness.create(self, ChapterFlow.build_squad(BattleCatalog.shipped()))
	auto_free(h.mode)
	h.reveal()
	DebugLaunchArgs.force_outcome(h.mode.battle, DebugLaunchArgs.VICTORY)
	h.mode.settle_replay()
	var panel: ResultsPanel = h.mode.results_panel()
	assert_bool(panel.visible).override_failure_message("no results screen after Victory").is_true()
	assert_str(panel.totals_text()).is_equal("+8 XP, +5 Money")  # the harness fight: one Clerk
