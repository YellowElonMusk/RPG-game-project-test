## Title mode scene (story 031; ADR-0002 §2: mode scenes extend `GameMode`;
## rule 12). New Game is focused on open and starts
## `request_transition(OVERWORLD)` after `SaveService.reset_all_to_new_game()`;
## Continue (story 090, ADR-0009 §6) is enabled when a slot exists and loads
## the latest one: read + preflight, and only a clean preflight requests the
## transition, with the `LoadedSave` as its payload. It stays in the focus
## chain regardless (default
## `Button.focus_mode`, untouched here) so GDD rule 12's lock glyph and
## unlock-reason tooltip can still show on focus; Settings goes nowhere until
## Settings exists; Quit opens `QuitConfirm`, a child panel of this scene,
## never a machine overlay (the Overlays table has no Quit overlay -- see
## `quit_confirm.gd`).
##
## Every step is driven through `handle_action()` from the synthetic
## `ActionSource` in tests, using story 030's `InterimFocusNav` helper
## (INTERIM tag, same as `DefeatPrompt`, pending ADR-0008's `FocusScope`/
## `UiNavigator`). The quit latch itself (Yes pressed twice in one frame
## still producing one call) is `GameStateMachine.request_quit()`'s own
## behavior (story 011) -- this scene calls it unconditionally on every
## `confirmed` signal and relies on that latch, rather than re-implementing it.
class_name TitleMode extends GameMode

## Not `@onready`: `ModeHostSceneLoader` calls `setup()` before `add_child()`
## (ADR-0002 Implementation Notes, story 030's note on `DefeatPrompt.setup()`
## applies equally to mode scenes), and `@onready` only resolves at
## `_ready()`. The `%` unique-name lookup itself does not need tree
## membership, so resolving them explicitly in `setup()` is what makes them
## available early enough to wire signals there.
var _new_game_button: Button = null
var _continue_button: Button = null
var _quit_button: Button = null
var _quit_confirm: QuitConfirm = null
## The focus root for `InterimFocusNav`: the script extends `GameMode`
## (a `Node`), so `self as Control` is a parse error on 4.7.2 even though the
## scene root is a `Control`.
var _buttons: Control = null

var _machine: GameStateMachine = null
## Injected by `GameRoot` before `setup()`; null in tests that do not need it.
var save_service: SaveService = null
## The last Continue preflight, for tests and the load report.
var last_load: LoadedSave = null


func setup(machine: GameStateMachine, _payload: RefCounted) -> void:
	_machine = machine
	_new_game_button = %NewGameButton
	_continue_button = %ContinueButton
	_quit_button = %QuitButton
	_quit_confirm = %QuitConfirm
	_buttons = $Buttons

	_continue_button.disabled = save_service == null or not save_service.has_any_save()
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_quit_confirm.configure()
	_quit_confirm.confirmed.connect(_on_quit_confirmed)
	_quit_confirm.cancelled.connect(_on_quit_cancelled)
	_quit_confirm.close()


## INTERIM (same tag as `DefeatPrompt._ready()`): this scene grabs its own
## initial focus, standing in for `UiService`'s `mode_entered` handoff
## (ADR-0008 §5) until `FocusScope` exists. AC-30: New Game is focused on open.
func _ready() -> void:
	# Looked up here, not via `_new_game_button`: the scene can enter the tree
	# before (or without) `setup()`.
	var new_game: Button = %NewGameButton
	new_game.grab_focus()


## `true` = consumed (ADR-0002 Key Interfaces). While `QuitConfirm` is open,
## every action is delegated to it instead -- it is a child panel of this
## scene, not a machine overlay, so there is no overlay-stack gate to rely on
## (ADR-0002 §2 Implementation Notes).
func handle_action(action: StringName, pressed: bool) -> bool:
	if _quit_confirm.visible:
		return _quit_confirm.handle_action(action, pressed)
	if not pressed:
		return true
	if action == InputActions.CONFIRM:
		InterimFocusNav.route_confirm(_buttons)
		return true
	if action == InputActions.NAV_UP:
		InterimFocusNav.route_direction(_buttons, SIDE_TOP)
		return true
	if action == InputActions.NAV_DOWN:
		InterimFocusNav.route_direction(_buttons, SIDE_BOTTOM)
		return true
	if action == InputActions.NAV_LEFT:
		InterimFocusNav.route_direction(_buttons, SIDE_LEFT)
		return true
	if action == InputActions.NAV_RIGHT:
		InterimFocusNav.route_direction(_buttons, SIDE_RIGHT)
		return true
	return true


func _on_new_game_pressed() -> void:
	if save_service != null:
		save_service.reset_all_to_new_game()
	if _machine != null:
		_machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)


## Story 090 (ADR-0009 §6): read and preflight the latest slot; a failed
## load is reported and requests nothing, so there is nothing to roll back.
## TODO(save-load): a slot list and the damaged-slot / backup prompt belong
## to the Save/Load GDD.
func _on_continue_pressed() -> void:
	if save_service == null or _machine == null:
		return
	last_load = save_service.preflight(save_service.read_slot(save_service.latest_slot()))
	if not last_load.is_ok():
		push_warning("Continue: slot %d did not load (status %d): %s"
				% [last_load.slot, last_load.status, ", ".join(last_load.report)])
		_continue_button.disabled = true
		return
	_machine.request_transition(GameStateMachine.Mode.OVERWORLD, last_load)


func _on_quit_pressed() -> void:
	_quit_confirm.open()


## Relies on `GameStateMachine.request_quit()`'s own latch (story 011) rather
## than guarding here -- a second `confirmed` in the same frame (AC-30: "Yes
## pressed twice in one frame still produces one call") reaches this twice,
## and the machine's `_quit_fired` flag absorbs the second call.
func _on_quit_confirmed() -> void:
	if _machine != null:
		_machine.request_quit()


func _on_quit_cancelled() -> void:
	_quit_confirm.close()
	_quit_button.grab_focus()
