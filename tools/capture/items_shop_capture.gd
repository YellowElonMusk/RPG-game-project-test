extends SceneTree
## Items & Shops in the real game: boots `GameRoot`, starts a New Game, gives
## the squad 60 money, rests at the Paris café and buys from its shop, then
## starts a Clerk fight with one member hurt and opens the Items command.
## Saves `01-camp.png`, `02-shop.png`, `03-battle-items.png` and
## `04-battle-item-target.png`, plus `05-menu-items.png` (the Overworld
## Menu's Items screen, taken before the fight). Needs a window and a GPU:
##
##   godot --path . -s res://tools/capture/items_shop_capture.gd [-- --out=res://dir/]

const DEFAULT_OUT: String = "res://production/qa/evidence/items-shop/"
const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const SAVE_DIR: String = "user://items_shop_capture_saves"
const SIZE := Vector2i(1280, 720)
const WAIT_CAP: int = 1200

var _root_node: GameRoot = null
var _out: String = DEFAULT_OUT


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_root_node = (load(GAME_ROOT_SCENE) as PackedScene).instantiate() as GameRoot
	_root_node.save_dir_override = SAVE_DIR
	root.add_child(_root_node)
	var m: GameStateMachine = _root_node.machine
	if m._action_source != null:
		m._unbind_action_source()
	var ok: bool = true
	await _wait_mode(GameStateMachine.Mode.TITLE)
	(_root_node.current_mode_node() as TitleMode)._on_new_game_pressed()
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	var ow: OverworldMode = _root_node.current_mode_node() as OverworldMode
	var ws: WorldState = ow.world_state
	ws.money = 60

	var camp_payload := CampEntryPayload.new()
	camp_payload.camp_id = "camp_paris_cafe"
	ok = _check("camp request", m.request_transition(GameStateMachine.Mode.CAMP, camp_payload) == GameStateMachine.RequestResult.OK) and ok
	await _frames(5)
	await _wait_mode(GameStateMachine.Mode.CAMP)
	await _frames(20)
	var camp: InterimCampMode = _root_node.current_mode_node() as InterimCampMode
	ok = _check("camp has a shop", camp.rows().has(InterimCampMode.SHOP)) and ok
	await _shot("01-camp")
	camp.handle_action(InputActions.NAV_DOWN, true)
	camp.handle_action(InputActions.CONFIRM, true)
	camp.handle_action(InputActions.CONFIRM, true)  # croissant
	camp.handle_action(InputActions.CONFIRM, true)  # croissant
	camp.handle_action(InputActions.NAV_DOWN, true)
	camp.handle_action(InputActions.CONFIRM, true)  # espresso
	await _frames(5)
	ok = _check("bought 2 croissants", ws.inventory.count("item_croissant") == 2) and ok
	ok = _check("bought 1 espresso", ws.inventory.count("item_espresso") == 1) and ok
	ok = _check("paid 28", ws.money == 60 - 2 * 8 - 12) and ok
	await _shot("02-shop")

	camp.handle_action(InputActions.CANCEL, true)
	camp.handle_action(InputActions.NAV_UP, true)
	camp.handle_action(InputActions.CONFIRM, true)  # set out
	await _frames(5)
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	ow = _root_node.current_mode_node() as OverworldMode
	var party: Array[Combatant] = []
	party.assign(ow.party_source.call())
	party[0].hp = 9
	m._on_source_action_pressed(&"menu")
	await _frames(10)
	var menu_overlay: InterimMenu = _root_node.current_overlay_node() as InterimMenu
	ok = _check("menu has Items", menu_overlay != null and menu_overlay.button_for(&"items") != null) and ok
	if menu_overlay != null and menu_overlay.button_for(&"items") != null:
		menu_overlay.button_for(&"items").emit_signal(&"pressed")
	await _frames(10)
	await _shot("05-menu-items")
	if menu_overlay != null:
		menu_overlay.handle_action(InputActions.CANCEL, true)
		menu_overlay.handle_action(InputActions.CANCEL, true)
	await _frames(10)
	var rec: EncounterData = _root_node.catalog().get_record(&"encounter", "enc_paris_clerks_hall") as EncounterData
	var payload := BattleEntryPayload.new()
	payload.descriptor = OverworldMode.build_descriptor(rec)
	payload.party.assign(party)
	ok = _check("battle request", m.request_transition(GameStateMachine.Mode.BATTLE, payload) == GameStateMachine.RequestResult.OK) and ok
	await _wait_mode(GameStateMachine.Mode.BATTLE)
	var menu: BattleCommandMenu = _find_menu(_root_node)
	var n: int = 0
	while (menu == null or not menu.visible) and n < WAIT_CAP:
		await process_frame
		menu = _find_menu(_root_node)
		n += 1
	await _frames(10)
	var items_button: Button = _button_starting(menu, "Items")
	ok = _check("Items entry enabled", items_button != null and not items_button.disabled) and ok
	if items_button != null:
		items_button.emit_signal(&"pressed")
	await _frames(10)
	await _shot("03-battle-items")
	var croissant: Button = _button_starting(menu, "Croissant")
	ok = _check("Croissant usable", croissant != null and not croissant.disabled) and ok
	if croissant != null:
		croissant.emit_signal(&"pressed")
	await _frames(10)
	await _shot("04-battle-item-target")
	print("items_shop_capture: %s; wrote %s" % ["PASS" if ok else "FAIL", _out])
	quit(0 if ok else 1)


func _find_menu(node: Node) -> BattleCommandMenu:
	if node is BattleCommandMenu:
		return node as BattleCommandMenu
	for child: Node in node.get_children():
		var found: BattleCommandMenu = _find_menu(child)
		if found != null:
			return found
	return null


func _button_starting(node: Node, prefix: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).is_visible_in_tree() and (node as Button).text.begins_with(prefix):
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _button_starting(child, prefix)
		if found != null:
			return found
	return null


func _check(label: String, cond: bool) -> bool:
	print("items_shop_capture: %s %s" % [label, "ok" if cond else "FAILED"])
	return cond


func _shot(name: String) -> void:
	for i: int in 3:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_out.path_join(name + ".png")))


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _wait_mode(mode: GameStateMachine.Mode) -> void:
	var m: GameStateMachine = _root_node.machine
	var n: int = 0
	while not (m.phase == GameStateMachine.Phase.IDLE and m.current_mode == mode) and n < WAIT_CAP:
		await process_frame
		n += 1


func _close_dialogues() -> void:
	var m: GameStateMachine = _root_node.machine
	var guard: int = 0
	while GameStateMachine.OverlayKind.DIALOGUE in m.overlay_stack and guard < 20:
		await _frames(4)
		var line: InterimLineDialogue = _root_node.current_overlay_node() as InterimLineDialogue
		if line != null:
			line.advance_guard(1.0)
			line.handle_action(InputActions.CONFIRM, true)
			line.handle_action(InputActions.CONFIRM, false)
		await _frames(4)
		guard += 1
