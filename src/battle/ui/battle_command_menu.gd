## The battle command menu (Story 007): on each squad turn, lists Attack,
## Defend and the active combatant's specials (`SquadMoves.moves_for()`),
## each with its MP cost; a move the active `FactionRule` currently forbids,
## or the combatant cannot afford, is shown disabled with the reason. Choosing
## a move that needs a target (`Move.TargetType.SINGLE_ENEMY`/`SINGLE_ALLY`)
## opens a target pick among the living valid targets; confirming submits the
## action through `BattleCore.submit_action()`, and cancel during the target
## pick returns to the command list. Hidden outside `SQUAD_TURN` and while
## Victory waits for its results confirm (`BattleMode` keeps that confirm's
## priority -- see `battle_mode.gd`'s `handle_action()`).
##
## Reads, never owns, battle state (Implementation Notes): this node only
## calls `BattleCore` getters and `submit_action()`, and never branches on
## which `FactionRule` subclass is active -- only its text hooks
## (`get_banner_text()`/`get_combatant_tooltip_note()`/`get_tooltip_text()`).
##
## Focus: `InterimFocusNav` (story 030's INTERIM helper) routes `confirm` and
## the four `nav_*` directions to whichever button has focus; every button
## gets explicit focus neighbours (Implementation Notes: headless geometric
## focus search proved unreliable in story 031).
##
## Usage example:
## [codeblock]
## var menu: BattleCommandMenu = preload("res://src/battle/ui/battle_command_menu.tscn").instantiate()
## add_child(menu)
## menu.setup(battle_core)
## # BattleMode.handle_action() forwards actions to menu.handle_action() while menu.visible.
## [/codeblock]
class_name BattleCommandMenu
extends Control

var _command_panel: PanelContainer = null
var _command_title: Label = null
var _command_list: VBoxContainer = null
var _target_panel: PanelContainer = null
var _target_title: Label = null
var _target_list: VBoxContainer = null

var _battle: BattleCore = null
## The Battle mode's replay controller (ADR-0006), or null. When set, the menu
## opens only on its `turn_started_after_replay` and closes on submit, so it
## stays hidden while the turn plays back (sprite-camera story 033).
var _replay: BattleReplayController = null
var _pending_move: Move = null


## Wires this menu to a battle: listens to `turn_started`/`battle_ended` to
## rebuild or hide itself, and shows the command list immediately if a squad
## turn is already active. Not `@onready`: `BattleMode.setup()` calls this
## before the menu is added to the tree (same note as `BattleHud`/
## `DefeatPrompt`'s own `setup()`), and the `%` unique-name lookup does not
## need tree membership.
##
## With `replay`, the menu connects only to the controller's gated turn and
## end signals, never to `BattleCore`'s (ADR-0006 Implementation Guidelines),
## and starts hidden unless the controller is already IDLE.
func setup(battle: BattleCore, replay: BattleReplayController = null) -> void:
	_command_panel = %CommandPanel
	_command_title = %CommandTitle
	_command_list = %CommandList
	_target_panel = %TargetPanel
	_target_title = %TargetTitle
	_target_list = %TargetList
	_battle = battle
	_replay = replay
	if _replay != null:
		_replay.turn_started_after_replay.connect(_on_turn_started)
		_replay.battle_ended_after_replay.connect(_on_battle_ended)
		if _replay.get_state() != BattleReplayController.State.IDLE:
			visible = false
			return
	else:
		_battle.turn_started.connect(_on_turn_started)
		_battle.battle_ended.connect(_on_battle_ended)
	_refresh_for_current_state()


## `true` = consumed. `BattleMode` forwards every action here while this menu
## is visible, after its own results-done confirm has had first refusal
## (Implementation Notes: "the existing results-done confirm keeps priority").
func handle_action(action: StringName, pressed: bool) -> bool:
	if not visible or not pressed:
		return false
	if action == InputActions.CONFIRM:
		return InterimFocusNav.route_confirm(self)
	if action == InputActions.CANCEL:
		return _handle_cancel()
	if action == InputActions.NAV_UP:
		return InterimFocusNav.route_direction(self, SIDE_TOP)
	if action == InputActions.NAV_DOWN:
		return InterimFocusNav.route_direction(self, SIDE_BOTTOM)
	if action == InputActions.NAV_LEFT:
		return InterimFocusNav.route_direction(self, SIDE_LEFT)
	if action == InputActions.NAV_RIGHT:
		return InterimFocusNav.route_direction(self, SIDE_RIGHT)
	return false


func _handle_cancel() -> bool:
	if not _target_panel.visible:
		return false
	_show_command_list()
	return true


func _refresh_for_current_state() -> void:
	if _battle == null or _battle.state != BattleCore.State.SQUAD_TURN:
		visible = false
		return
	visible = true
	_show_command_list()


func _show_command_list() -> void:
	_pending_move = null
	_target_panel.visible = false
	_command_panel.visible = true
	_rebuild_command_list()


func _rebuild_command_list() -> void:
	_clear(_command_list)
	var actor: Combatant = _battle.get_active_combatant()
	if actor == null:
		return
	_command_title.text = "%s's turn" % actor.display_name
	var buttons: Array[Button] = []
	for move: Move in SquadMoves.moves_for(actor):
		buttons.append(_make_command_button(actor, move))
	for button in buttons:
		_command_list.add_child(button)
	_wire_vertical_neighbors(buttons)
	_focus_first_enabled(buttons)


func _make_command_button(actor: Combatant, move: Move) -> Button:
	var reason: String = _disabled_reason(actor, move)
	var button := Button.new()
	button.text = "%s (MP %d)" % [move.display_name, move.mp_cost] if reason.is_empty() \
			else "%s (MP %d) -- %s" % [move.display_name, move.mp_cost, reason]
	button.tooltip_text = reason
	# The menu is a narrow column beside the stage (BattleHud.COLUMN_WIDTH).
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = not reason.is_empty()
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_on_move_chosen.bind(move))
	return button


## `""` if `move` is usable by `actor` right now, else the reason to show
## beside it -- the same precedence `BattleCore.submit_action()` itself
## checks (faction special ban, then faction `move_allowed()`, then
## affordability), so a move disabled here is also rejected there. Only
## `FactionRule`'s existing text hooks (Implementation Notes: "Write no
## per-faction branches in the menu").
func _disabled_reason(actor: Combatant, move: Move) -> String:
	var rule: FactionRule = _battle.faction_rule
	if move.category == Move.Category.SPECIAL and not rule.specials_allowed(_battle.round_number):
		return rule.get_banner_text(_battle.round_number)
	if not rule.move_allowed(actor, move):
		var note: String = rule.get_combatant_tooltip_note(actor)
		return note if not note.is_empty() else rule.get_tooltip_text(_battle.round_number)
	if not actor.can_afford(move.mp_cost):
		return "Not enough MP (needs %d)" % move.mp_cost
	return ""


func _on_move_chosen(move: Move) -> void:
	if move.target_type == Move.TargetType.SELF:
		_submit(move, null)
		return
	_pending_move = move
	_show_target_pick(move)


func _show_target_pick(move: Move) -> void:
	_command_panel.visible = false
	_target_panel.visible = true
	_clear(_target_list)
	var targets: Array[Combatant] = _battle.get_living_enemies() \
			if move.target_type == Move.TargetType.SINGLE_ENEMY else _battle.get_living_squad()
	_target_title.text = "%s -- choose a target" % move.display_name
	var buttons: Array[Button] = []
	for target: Combatant in targets:
		var button := Button.new()
		button.text = target.display_name
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_target_chosen.bind(move, target))
		buttons.append(button)
	for button in buttons:
		_target_list.add_child(button)
	_wire_vertical_neighbors(buttons)
	if not buttons.is_empty():
		_grab_focus_now_and_deferred(buttons[0])


func _on_target_chosen(move: Move, target: Combatant) -> void:
	_submit(move, target)


func _submit(move: Move, target: Combatant) -> void:
	_pending_move = null
	if _replay != null:
		visible = false
	_battle.submit_action(move, target)


func _focus_first_enabled(buttons: Array[Button]) -> void:
	for button in buttons:
		if not button.disabled:
			_grab_focus_now_and_deferred(button)
			return


## Chains each button to the next/previous as its top/bottom focus
## neighbours (Implementation Notes: "buttons get explicit focus
## neighbours") -- a plain vertical list, since both panels here are single
## columns.
func _wire_vertical_neighbors(buttons: Array[Button]) -> void:
	for i in buttons.size():
		var button: Button = buttons[i]
		var path_up: NodePath = button.get_path_to(buttons[i - 1]) if i > 0 else NodePath()
		var path_down: NodePath = button.get_path_to(buttons[i + 1]) if i < buttons.size() - 1 else NodePath()
		button.focus_neighbor_top = path_up
		button.focus_neighbor_bottom = path_down
		button.focus_previous = path_up
		button.focus_next = path_down


func _clear(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _on_turn_started(_combatant: Combatant) -> void:
	_refresh_for_current_state()


func _on_battle_ended(_won: bool) -> void:
	visible = false


## Focuses `button` now (works when the menu is already in the tree and
## visible, as in tests) and again once deferred: the menu can rebuild on
## `turn_started` before it enters the tree, where `grab_focus()` silently
## does nothing, leaving keyboard and pad players with no visible selection.
func _grab_focus_now_and_deferred(button: Button) -> void:
	if button.is_inside_tree() and button.is_visible_in_tree():
		button.grab_focus()
	button.grab_focus.call_deferred()
