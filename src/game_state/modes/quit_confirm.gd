## Reusable Yes/No confirmation panel (story 031; ADR-0002 §2 Implementation
## Notes: "quit_confirm is a child panel of Title, not a machine overlay").
## Opens with No focused (AC-30); `confirm`/`cancel`/direction route through
## `InterimFocusNav`, the same INTERIM tag as `DefeatPrompt` (story 030)
## pending ADR-0008's `FocusScope`/`UiNavigator`. This panel never touches
## `GameStateMachine` -- the owner (`TitleMode` here; the Menu's Quit
## confirmation later, per this story's Implementation Notes) decides what
## "confirmed" means and wires `machine.request_quit()` itself, so the same
## scene is reusable as-is once the UI Framework epic builds the Menu.
##
## ADR-0009 §4: the wording below is the pre-Save/Load default ("all progress
## will be lost"); `has_unsaved_progress()` will drive it once Save/Load
## exists. ADR-0013: this is player-facing text and goes through localization
## when that epic lands -- no string table is built here.
class_name QuitConfirm extends Control

## Fired when Yes is pressed (`confirm` while Yes is focused, or a direct
## click). The owner decides what "quit" means.
signal confirmed()

## Fired when No is pressed, or `cancel` is pressed while this panel is open.
## Kept distinct from `confirmed` so the owner never has to guess why this
## panel wants to close.
signal cancelled()

## Not `@onready`: whichever scene instances this panel (`TitleMode.setup()`,
## same note as `DefeatPrompt.setup()`, story 030) may call `configure()`
## before this node is added to a tree. The `%` unique-name lookup itself
## does not need tree membership -- a scene's owner links are set at
## `instantiate()` time -- so resolving them explicitly here is what makes
## them available early enough.
var _yes_button: Button = null
var _no_button: Button = null


## Resolves this panel's buttons and wires their `pressed` signals. Call once,
## before this node is added to a tree.
func configure() -> void:
	_yes_button = %YesButton
	_no_button = %NoButton
	_yes_button.pressed.connect(_on_yes_pressed)
	_no_button.pressed.connect(_on_no_pressed)


## Shows this panel and focuses No (AC-30: "a confirmation opens with No
## focused").
func open() -> void:
	show()
	_no_button.grab_focus()


func close() -> void:
	hide()


## `true` = consumed. Intended to be called only while `visible` is true (the
## owner's `handle_action()` is responsible for that gate, same pattern as
## `GameStateMachine._dispatch_discrete_action()` gating on the overlay
## stack). `cancel` and the unhandled default both consume and change nothing
## beyond firing `cancelled`/doing nothing (AC-30: "`cancel` closes it without
## quitting").
func handle_action(action: StringName, pressed: bool) -> bool:
	if not pressed:
		return true
	if action == InputActions.CONFIRM:
		InterimFocusNav.route_confirm(self)
		return true
	if action == InputActions.CANCEL:
		cancelled.emit()
		return true
	if action == InputActions.NAV_UP:
		InterimFocusNav.route_direction(self, SIDE_TOP)
		return true
	if action == InputActions.NAV_DOWN:
		InterimFocusNav.route_direction(self, SIDE_BOTTOM)
		return true
	if action == InputActions.NAV_LEFT:
		InterimFocusNav.route_direction(self, SIDE_LEFT)
		return true
	if action == InputActions.NAV_RIGHT:
		InterimFocusNav.route_direction(self, SIDE_RIGHT)
		return true
	return true


func _on_yes_pressed() -> void:
	confirmed.emit()


func _on_no_pressed() -> void:
	cancelled.emit()
