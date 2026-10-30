## Routes a Battle-mode press during a replay to the latch (ADR-0006 §6
## "Input routing"; GDD sprite-camera-presentation AC-38). The Battle mode's
## `handle_action()` calls `route()` first; a `true` return means the press
## was consumed and must never reach the command menu, a buffer or the Menu.
##
## Usage example:
## [codeblock]
## func handle_action(action: StringName) -> void:
##     if ReplayInputRouter.route(replay, action, ui.play_refusal):
##         return
##     command_menu.handle_action(action)
## [/codeblock]
class_name ReplayInputRouter
extends RefCounted

## The Input System's Confirm action.
const ACTION_CONFIRM: StringName = &"confirm"
## The Input System's fast-forward action.
const ACTION_FAST_FORWARD: StringName = &"fast_forward"
## The Input System's Cancel action.
const ACTION_CANCEL: StringName = &"cancel"
## The UI Framework's replay-indicator click, reported as its own event.
const ACTION_INDICATOR_CLICK: StringName = &"replay_indicator_click"

## Indicator states (`indicator_state()`).
const INDICATOR_HIDDEN: StringName = &""
const INDICATOR_PASSIVE: StringName = &"passive"
const INDICATOR_ACTIVE: StringName = &"active"
const INDICATOR_LATCHED: StringName = &"latched"


## Routes one `pressed` action. While replaying, Confirm / fast_forward
## latch, Cancel un-latches and an indicator click toggles; a press that
## changes nothing calls `refuse` exactly once. While GATED these presses
## are consumed and do nothing. Returns true when the press was consumed.
static func route(controller: BattleReplayController, action: StringName, refuse: Callable) -> bool:
	if not _is_replay_action(action):
		return false
	if controller.is_replaying():
		var changed: bool
		match action:
			ACTION_CANCEL:
				changed = controller.clear_latch()
			ACTION_INDICATOR_CLICK:
				changed = controller.clear_latch() if controller.is_latched() else controller.request_latch()
			_:
				changed = controller.request_latch()
		if not changed and refuse.is_valid():
			refuse.call()
		return true
	return controller.get_state() == BattleReplayController.State.GATED


## The replay indicator's state for this frame: hidden outside a replay,
## passive while no press would change anything, else latched or active.
static func indicator_state(controller: BattleReplayController) -> StringName:
	if not controller.is_replaying():
		return INDICATOR_HIDDEN
	if not controller.is_press_effective():
		return INDICATOR_PASSIVE
	return INDICATOR_LATCHED if controller.is_latched() else INDICATOR_ACTIVE


static func _is_replay_action(action: StringName) -> bool:
	return action == ACTION_CONFIRM or action == ACTION_FAST_FORWARD \
			or action == ACTION_CANCEL or action == ACTION_INDICATOR_CLICK
