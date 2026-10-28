## The Content Error mode scene (story 035; ADR-0002 Migration Plan Step 2,
## TR-gamestate-005). Reached only from `BOOT` when the catalog is `FAILED`
## (`GameStateMachine._tick_boot()`); terminal (ADR-0002 §5) -- every control
## but Quit is a no-op. Plain text from
## `ValidationReportText.build_error_screen_text()`; the full log is written
## to `LOG_PATH` via `build_log_text()`. Not translated (ADR-0013): this has
## to work even when the content that failed to load is localization data
## itself, so no art, animation or faction styling is used here.
class_name ContentErrorMode
extends GameMode

## `user://` log path named in the on-screen text (GDD F4).
const LOG_PATH: String = "user://content_errors.log"
## Most errors the screen lists (GDD F4 Tuning Knobs default). This mode uses
## the shipped default directly -- `ContentReportConfig` is for
## `validate-content.gd` and future callers that need the configurable cap.
const _CAP: int = 20

var _machine: GameStateMachine = null
var _label: Label = null
var _quit_button: Button = null
## The focus root for `InterimFocusNav`: the script extends `GameMode` (a
## `Node`), so `self as Control` is a parse error on 4.7.2 even though the
## scene root is a `Control` (same note as `TitleMode._buttons`).
var _layout: Control = null

## Test seam (the subprocess harness, this story's Check 2): the exact text
## shown on screen, without a second `%ReportLabel` lookup from outside this
## scene (`%Unique` names resolve only within their owning sub-scene).
var report_text: String:
	get:
		return _label.text if _label != null else ""


## Not `@onready`: `ModeHostSceneLoader` calls `setup()` before `add_child()`
## (ADR-0002 Implementation Notes, same note as `TitleMode.setup()`), and
## `@onready` only resolves at `_ready()`. The `%` unique-name lookup itself
## does not need tree membership, so resolving them here is what makes them
## available early enough to wire signals and build the on-screen text.
func setup(machine: GameStateMachine, _payload: RefCounted) -> void:
	_machine = machine
	_layout = $Layout
	_label = %ReportLabel
	_quit_button = %QuitButton
	_quit_button.pressed.connect(_on_quit_pressed)
	# The autoload via the main loop, not its identifier (see GameRoot.catalog()):
	# setup() runs before this node is in the tree.
	var report: Array[Dictionary] = ((Engine.get_main_loop() as SceneTree).root.get_node(^"ContentCatalog") as ContentCatalogService).report
	_label.text = ValidationReportText.build_error_screen_text(report, _CAP, LOG_PATH)
	_write_log(report)


## INTERIM (same tag as `TitleMode`/`DefeatPrompt`): grabs its own initial
## focus, standing in for `UiService`'s `mode_entered` handoff (ADR-0008 §5)
## until `FocusScope` exists.
func _ready() -> void:
	var quit_button: Button = %QuitButton
	quit_button.grab_focus()


## `true` = consumed (ADR-0002 Key Interfaces). Only Quit is actionable
## (Check 2): `confirm` routes to whichever control is focused -- the only
## one is Quit -- and every other action is consumed without effect.
func handle_action(action: StringName, pressed: bool) -> bool:
	if not pressed:
		return true
	if action == InputActions.CONFIRM:
		InterimFocusNav.route_confirm(_layout)
	return true


func _on_quit_pressed() -> void:
	if _machine != null:
		_machine.request_quit()


func _write_log(report: Array[Dictionary]) -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ContentErrorMode: failed to open %s for writing (error %d)." \
				% [LOG_PATH, FileAccess.get_open_error()])
		return
	file.store_string(ValidationReportText.build_log_text(report))
