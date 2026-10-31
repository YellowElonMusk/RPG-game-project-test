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

## The input guard (GDD rule 9, ADR-0008 §6; sprite-camera story 058): the
## Defeat Prompt is one of the four guarded screens. Opened in `_ready()` on
## the machine's mode-time clock; `input_guard` comes from this config.
var presentation_config: PresentationConfig = PresentationConfig.new()
## Actions held right now (`held_now` for `MenuGuard`): `UiService`'s held
## mirror once it exists; until then nothing is reported held (the resolver
## sends one press per physical press, so a held key never re-presses).
var held_actions_source: Callable = func() -> Array[StringName]: return []
## Refusal feedback for a refused press (ADR-0008 §7).
var feedback: UiFeedback = UiFeedback.new()

var _guard: MenuGuard = null


## The prompt's `MenuGuard` (tests and the UI service read it).
func guard() -> MenuGuard:
	return _guard


func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	_guard = MenuGuard.new(_mode_time, func() -> Array[StringName]: return held_actions_source.call(),
			presentation_config.input_guard)
	_guard.refused.connect(func(_action: StringName) -> void:
			feedback.refuse(get_viewport().gui_get_focus_owner() if is_inside_tree() else null))
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
## The default focus is `MenuDefaultFocus.DEFEAT_PROMPT` (Retry); the guard
## window opens here, when the prompt is on screen.
func _ready() -> void:
	_default_focus_button().grab_focus()
	if _guard == null:
		setup(_machine, null)
	_guard.open(self)


## Removes the guard's blocker once the window has passed.
func _process(_delta: float) -> void:
	if _guard != null:
		_guard.tick()


func _mode_time() -> float:
	return _machine.mode_time if _machine != null else 0.0


func _default_focus_button() -> Button:
	if MenuDefaultFocus.DEFEAT_PROMPT == &"retreat" and _retreat_button != null:
		return _retreat_button
	return _retry_button


## `true` = consumed (ADR-0002 Key Interfaces). `cancel` and the unhandled
## default both consume and change nothing (AC-29: "cancel changes
## nothing"). `menu` never reaches here — the machine intercepts it before
## routing (story 024). Every action first passes the `MenuGuard`: a press
## inside `input_guard` is refused (with feedback), a carried-over held
## action is swallowed silently.
func handle_action(action: StringName, pressed: bool) -> bool:
	if _guard != null and _guard.filter(action, pressed) != MenuGuard.Verdict.PASS:
		return true
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
