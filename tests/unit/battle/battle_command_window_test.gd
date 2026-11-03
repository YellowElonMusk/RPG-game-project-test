## Regression (story 060 Finding 1; GDD sprite-camera-presentation rule 13
## "Flash limit", AC-55b; art bible "navy and cream windows"): the command
## menu's dark panel used to appear and disappear with the menu every turn, a
## large-area luminance swing (~32% of a 10-degree window) that made 3-4
## ungated flashes a second. The command area is now one persistent window
## for the whole battle; opening and closing the menu changes only its
## contents, and the menu's own panels draw no second background over it.
extends GdUnitTestSuite

## Skipped until the CommandWindow fix lands: watched failing against the
## current code ("no persistent command window"), fix not yet implemented.
## Remove the do_skip arguments when it lands.
const _PENDING: String = "story 060 Finding 1: persistent command window not implemented yet"


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _harness() -> BattleModeHarness:
	var h := BattleModeHarness.create(self, ChapterFlow.build_squad(BattleCatalog.shipped()))
	auto_free(h.mode)
	return h


func _window(h: BattleModeHarness) -> Control:
	return h.mode.get_node_or_null(^"%CommandWindow") as Control


func test_command_window_stays_visible_while_the_menu_closes_for_a_replay() -> void:
	var h := _harness()
	var menu: BattleCommandMenu = h.mode.get_node(^"%BattleCommandMenu")
	assert_object(_window(h)).override_failure_message("no persistent command window").is_not_null()
	if _window(h) == null:
		return
	assert_bool(_window(h).is_visible_in_tree()).override_failure_message(
			"command window hidden before the reveal (it must arrive with the battle)").is_true()
	h.reveal()
	assert_bool(menu.visible).is_true()
	assert_bool(_window(h).is_visible_in_tree()).is_true()
	h.press(InputActions.CONFIRM)  # Attack
	h.press(InputActions.CONFIRM)  # first target
	assert_bool(menu.visible).override_failure_message("menu still open during the replay").is_false()
	assert_bool(_window(h).is_visible_in_tree()).override_failure_message(
			"command window vanished with the menu: a large-area flash every turn").is_true()
	h.mode.settle_replay()
	assert_bool(menu.visible).is_true()
	assert_bool(_window(h).is_visible_in_tree()).is_true()


func test_menu_panels_draw_no_second_background_over_the_window() -> void:
	var h := _harness()
	h.reveal()
	var menu: BattleCommandMenu = h.mode.get_node(^"%BattleCommandMenu")
	for panel_name: String in ["%CommandPanel", "%TargetPanel"]:
		var panel: PanelContainer = menu.get_node(NodePath(panel_name))
		assert_bool(panel.get_theme_stylebox(&"panel") is StyleBoxEmpty).override_failure_message(
				"%s draws its own panel over the command window" % panel_name).is_true()


func test_command_window_covers_the_menu_panel() -> void:
	var h := _harness()
	h.reveal()
	await await_idle_frame()  # the window fits once layout has settled
	var window: Control = _window(h)
	assert_object(window).is_not_null()
	if window == null:
		return
	var panel: Control = h.mode.get_node(^"%BattleCommandMenu").get_node(^"%CommandPanel")
	var w: Rect2 = window.get_global_rect()
	var p: Rect2 = panel.get_global_rect()
	assert_bool(w.encloses(p)).override_failure_message(
			"menu panel %s spills out of the window %s" % [p, w]).is_true()


## The window shares the left column with the squad cards and can grow up
## behind them on a long command list; it must draw under the HUD, never over
## the cards.
func test_command_window_draws_behind_the_squad_cards() -> void:
	var h := _harness()
	var window: Control = _window(h)
	assert_object(window).is_not_null()
	if window == null:
		return
	var hud: Control = h.mode.get_node(^"%BattleHud")
	assert_int(window.get_index()).override_failure_message(
			"command window draws over the HUD's squad cards").is_less(hud.get_index())


## The window grows only as tall as the tallest command list it has held, so
## it never swallows the squad column above the menu. Goes through a target
## pick and a replay: a panel's first layout pass measures its wrapped
## buttons at near-zero width (600+ px tall for one frame), and the window
## used to lock that height in.
func test_command_window_is_no_taller_than_the_tallest_settled_panel() -> void:
	var h := _harness()
	var window: Control = _window(h)
	assert_object(window).is_not_null()
	if window == null:
		return
	var menu: Node = h.mode.get_node(^"%BattleCommandMenu")
	var command_panel: Control = menu.get_node(^"%CommandPanel")
	var target_panel: Control = menu.get_node(^"%TargetPanel")
	h.reveal()
	await await_idle_frame()
	var tallest: float = command_panel.size.y
	h.press(InputActions.CONFIRM)  # Attack: opens the target pick
	await await_idle_frame()
	tallest = maxf(tallest, target_panel.size.y)
	h.press(InputActions.CONFIRM)  # first target: the replay plays
	h.mode.settle_replay()
	await await_idle_frame()
	tallest = maxf(tallest, command_panel.size.y)
	assert_float(window.size.y).override_failure_message(
			"window %.0f px tall for at most a %.0f px command list" % [window.size.y, tallest]).is_less_equal(tallest + 1.0)
