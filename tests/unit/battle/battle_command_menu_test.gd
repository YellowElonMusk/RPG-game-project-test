## Story 007 QA Test Cases: a real `BattleCore` with the real squad and a
## Bureaucratia Clerk, driving `BattleCommandMenu` the same way `BattleMode`
## does (`setup()`, then `handle_action()`). No new cases invented.
extends GdUnitTestSuite


## The roster and specials factories read the shipped catalog (content-migration
## stories 024/028), so boot it once for this suite.
func before() -> void:
	BattleContentSeam.ensure_catalog()

const _MENU_SCENE: String = "res://src/battle/ui/battle_command_menu.tscn"
const _CHARACTER_IDS: Array[String] = [
	"char_baguette_thrower", "char_florida_man", "char_karen", "char_michelin_chef",
]


func test_shows_active_combatants_moves_with_costs() -> void:
	var menu: BattleCommandMenu = _build_menu()
	var battle: BattleCore = _make_bureaucratia_battle(menu)

	var command_list: VBoxContainer = menu.get_node("%CommandList")
	var command_panel: PanelContainer = menu.get_node("%CommandPanel")
	assert_bool(command_panel.visible).is_true()

	var actor: Combatant = battle.get_active_combatant()
	var expected_moves: Array[Move] = SquadMoves.moves_for(actor)
	assert_int(command_list.get_child_count()).is_equal(expected_moves.size())
	for i in expected_moves.size():
		var button: Button = command_list.get_child(i)
		assert_str(button.text).override_failure_message(
				"button %d text: %s" % [i, button.text]).contains(
				"%s (MP %d)" % [expected_moves[i].display_name, expected_moves[i].mp_cost])


func test_specials_disabled_under_bureaucratia_permit_ban_with_reason() -> void:
	var menu: BattleCommandMenu = _build_menu()
	var battle: BattleCore = _make_bureaucratia_battle(menu)
	var rule := BureaucratiaRule.new()
	var expected_reason: String = rule.get_banner_text(battle.round_number)

	var command_list: VBoxContainer = menu.get_node("%CommandList")
	var special_button: Button = _find_button(command_list, "Home Run")
	assert_object(special_button).override_failure_message(
			"no Home Run button found").is_not_null()
	assert_bool(special_button.disabled).override_failure_message(
			"Home Run should be disabled under the permit ban").is_true()
	assert_str(special_button.tooltip_text).is_equal(expected_reason)


func test_confirm_attack_then_confirm_target_submits_and_damages_enemy() -> void:
	var menu: BattleCommandMenu = _build_menu()
	var battle: BattleCore = _make_bureaucratia_battle(menu)
	var clerk: Combatant = battle.enemies[0]
	var starting_hp: int = clerk.hp

	menu.handle_action(InputActions.CONFIRM, true)  # Attack -> opens target pick
	var target_panel: PanelContainer = menu.get_node("%TargetPanel")
	assert_bool(target_panel.visible).override_failure_message(
			"target pick did not open after Attack").is_true()
	menu.handle_action(InputActions.CONFIRM, true)  # confirm the first (only) enemy

	assert_int(clerk.hp).override_failure_message(
			"clerk hp did not drop after the submitted Attack").is_less(starting_hp)


func test_cancel_in_target_pick_returns_to_list_with_no_action_submitted() -> void:
	var menu: BattleCommandMenu = _build_menu()
	var battle: BattleCore = _make_bureaucratia_battle(menu)
	var outcomes_before: int = battle.outcome_log.size()

	menu.handle_action(InputActions.CONFIRM, true)  # Attack -> opens target pick
	var target_panel: PanelContainer = menu.get_node("%TargetPanel")
	var command_panel: PanelContainer = menu.get_node("%CommandPanel")
	assert_bool(target_panel.visible).is_true()

	var consumed: bool = menu.handle_action(InputActions.CANCEL, true)

	assert_bool(consumed).override_failure_message("cancel was not consumed").is_true()
	assert_bool(target_panel.visible).override_failure_message(
			"target pick still open after cancel").is_false()
	assert_bool(command_panel.visible).override_failure_message(
			"command list did not reopen after cancel").is_true()
	assert_int(battle.outcome_log.size()).override_failure_message(
			"an action was submitted despite cancel").is_equal(outcomes_before)


func test_defend_submits_with_no_target_pick() -> void:
	var menu: BattleCommandMenu = _build_menu()
	var battle: BattleCore = _make_bureaucratia_battle(menu)
	var outcomes_before: int = battle.outcome_log.size()

	menu.handle_action(InputActions.NAV_DOWN, true)  # Attack -> Defend
	menu.handle_action(InputActions.CONFIRM, true)  # Defend has no target

	var target_panel: PanelContainer = menu.get_node("%TargetPanel")
	assert_bool(target_panel.visible).override_failure_message(
			"Defend opened a target pick").is_false()
	assert_int(battle.outcome_log.size()).override_failure_message(
			"Defend was not submitted").is_equal(outcomes_before + 1)
	assert_int(battle.outcome_log.back().category).is_equal(Move.Category.DEFEND)


func test_menu_hidden_after_battle_ended() -> void:
	var menu: BattleCommandMenu = _build_menu()
	var battle: BattleCore = _make_bureaucratia_battle(menu)
	assert_bool(menu.visible).is_true()

	battle.battle_ended.emit(true)

	assert_bool(menu.visible).override_failure_message(
			"menu still visible after battle_ended").is_false()


func test_unaffordable_special_disabled_with_mp_reason() -> void:
	var squad: Array[Combatant] = _make_real_squad()
	squad[0].mp = 0  # Baguette Thrower: Home Run's cost comes from its Move record
	var battle := BattleCore.new(squad, [BureaucratiaRule.make_clerk()],
			RandomNumberGenerator.new(), FactionRule.new())
	battle.start_battle(false)
	var menu: BattleCommandMenu = _build_menu()
	menu.setup(battle)

	var command_list: VBoxContainer = menu.get_node("%CommandList")
	var special_button: Button = _find_button(command_list, "Home Run")
	assert_object(special_button).override_failure_message(
			"no Home Run button found").is_not_null()
	assert_bool(special_button.disabled).override_failure_message(
			"Home Run should be disabled with 0 MP").is_true()
	assert_str(special_button.tooltip_text).is_equal(
			"Not enough MP (needs %d)" % SquadSpecials.make_home_run().mp_cost)


func _build_menu() -> BattleCommandMenu:
	var menu: BattleCommandMenu = preload(_MENU_SCENE).instantiate()
	add_child(menu)
	auto_free(menu)
	return menu


## A real BattleCore, the real four-character squad and a single Bureaucratia
## Clerk, at round 1 (specials banned) -- the menu's `setup()` already called.
func _make_bureaucratia_battle(menu: BattleCommandMenu) -> BattleCore:
	var squad: Array[Combatant] = _make_real_squad()
	var battle := BattleCore.new(squad, [BureaucratiaRule.make_clerk()],
			RandomNumberGenerator.new(), BureaucratiaRule.new())
	battle.start_battle()
	menu.setup(battle)
	return battle


## The real squad (Story 007): the four `char_*` records, sorted by id, the
## same order `ChapterMode._default_squad()` builds.
func _make_real_squad() -> Array[Combatant]:
	var squad: Array[Combatant] = []
	for id: String in _CHARACTER_IDS:
		var record: CharacterData = ResourceLoader.load(
				"res://data/characters/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterData
		var combatant := Combatant.new(record.display_name, record.max_hp,
				record.max_mp, record.attack, record.defense, record.speed, false)
		combatant.move_ids = record.move_ids
		squad.append(combatant)
	return squad


func _find_button(container: VBoxContainer, display_name_prefix: String) -> Button:
	for child in container.get_children():
		var button: Button = child as Button
		if button != null and button.text.begins_with(display_name_prefix):
			return button
	return null
