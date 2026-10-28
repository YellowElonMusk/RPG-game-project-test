## The Defeat Prompt overlay (ADR-0002 §7-8, story 017/018; AC-29). Opens
## with Retry focused; Retreat exists only when
## `DefeatPromptPayload.offers_retreat`. `cancel` does nothing; `confirm` and
## the direction actions route through `InterimFocusNav`, tagged INTERIM
## below (ADR-0008 §3/§5's `UiNavigator`/`FocusScope` own this once they
## exist; "interim deviation" from the control manifest's "`UiService`, not
## each overlay, grabs focus for an overlay").
class_name DefeatPrompt extends GameOverlay

## Not `@onready`: `ModeHostSceneLoader.push_overlay()` calls `setup()`
## before `add_child()` (ADR-0002 Implementation Notes, story 030), and
## `@onready` only resolves at `_ready()` (node-enters-tree time). The `%`
## unique-name lookup itself does not need tree membership — a scene's
## owner links are set at `instantiate()` time — so resolving them
## explicitly in `setup()` is what makes them available early enough.
var _retry_button: Button = null
var _retreat_button: Button = null

var _machine: GameStateMachine = null


func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	_retry_button = %RetryButton
	_retreat_button = %RetreatButton
	var prompt_payload: DefeatPromptPayload = payload as DefeatPromptPayload
	var offers_retreat: bool = prompt_payload != null and prompt_payload.offers_retreat
	if offers_retreat:
		_retreat_button.pressed.connect(_on_retreat_pressed)
	else:
		# AC-29 edge case: the Retreat button is absent, not merely hidden,
		# when the payload does not offer it.
		_retreat_button.queue_free()
		_retreat_button = null
	_retry_button.pressed.connect(_on_retry_pressed)
	if _machine != null:
		_machine.overlay_closed.connect(_on_overlay_closed)


## INTERIM (same tag as `_on_overlay_closed()` below): this overlay grabs its
## own focus on becoming the top overlay, standing in for `UiService`'s
## `overlay_opened` handoff (ADR-0008 §5) until `FocusScope` exists.
func _ready() -> void:
	_retry_button.grab_focus()


## `true` = consumed (ADR-0002 Key Interfaces). `cancel` and the unhandled
## default both consume and change nothing (AC-29: "cancel changes
## nothing"). `menu` never reaches here — the machine intercepts it before
## routing (story 024).
func handle_action(action: StringName, pressed: bool) -> bool:
	if not pressed:
		return true
	if action == InputActions.CONFIRM:
		InterimFocusNav.route_confirm(self)
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


## INTERIM (see `_ready()`): regrabs focus on Retry once the Menu opened
## over this prompt (story 024's `_MENU_ALLOWED_MODES`, which treats Battle
## with the Defeat Prompt on top as allowed) closes and this prompt is back
## on top of the stack.
func _on_overlay_closed(kind: GameStateMachine.OverlayKind) -> void:
	if kind != GameStateMachine.OverlayKind.MENU:
		return
	if _machine == null or _machine.overlay_stack.is_empty():
		return
	if _machine.overlay_stack.back() != GameStateMachine.OverlayKind.DEFEAT_PROMPT:
		return
	_retry_button.grab_focus()


func _on_retry_pressed() -> void:
	if _machine != null:
		_machine.choose_retry()


func _on_retreat_pressed() -> void:
	if _machine != null:
		_machine.choose_retreat()
