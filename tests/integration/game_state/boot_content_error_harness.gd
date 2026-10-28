extends SceneTree
## Headless driver for the Check 2 subprocess (story 035): `ContentCatalog`
## is a one-shot autoload (`ContentBootstrap.run()` is a no-op after the
## first call in a process), so a `FAILED`-root scenario needs a fresh
## process of its own -- the same reason
## `content_data_validate_cli_test.gd` drives `validate-content.gd` this way,
## and `.claude/scripts/godot-parse-check.gd`'s own `_initialize()` timing
## note that an autoload's `_ready()` runs after a `-s` script's own
## `_initialize()`.
##
## Boots the real `game_root.tscn` -- `--data-root=<fixture>` reaches it
## exactly as it would in production, through `GameRoot.resolve_data_root()`
## reading `OS.get_cmdline_user_args()` -- ticks every frame via the
## `_process()` MainLoop override until the machine is idle outside `BOOT`,
## then prints `MODE=<int>`, `FALLBACK=<bool>` and the Content Error label's
## text between `TEXT_START`/`TEXT_END` markers, and quits 0 (or prints
## `TIMEOUT` and quits 1 if it never settles).

const _MAX_TICKS: int = 600

var _game_root: GameRoot
var _ticks: int = 0


func _initialize() -> void:
	_game_root = preload("res://src/game_state/game_root.tscn").instantiate()
	root.add_child(_game_root)


func _process(_delta: float) -> bool:
	_ticks += 1
	# Checked first, so a broken boot (null GameRoot) still ends the process.
	if _ticks > _MAX_TICKS:
		print("TIMEOUT")
		quit(1)
		return true
	if _game_root == null:
		return false
	var machine: GameStateMachine = _game_root.machine
	if machine != null and machine.phase == GameStateMachine.Phase.IDLE \
			and machine.current_mode != GameStateMachine.Mode.BOOT:
		_report()
		return true
	if _ticks > _MAX_TICKS:
		print("TIMEOUT")
		quit(1)
		return true
	return false


func _report() -> void:
	var machine: GameStateMachine = _game_root.machine
	print("MODE=%d" % machine.current_mode)
	print("FALLBACK=%s" % _game_root.used_fallback_bindings)
	var mode_node: ContentErrorMode = _game_root.current_mode_node() as ContentErrorMode
	print("TEXT_START")
	print(mode_node.report_text if mode_node != null else "")
	print("TEXT_END")
	quit(0)
