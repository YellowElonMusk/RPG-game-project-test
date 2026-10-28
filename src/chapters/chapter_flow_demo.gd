## Boots the MVP loop through `GameRoot` for manual/visual verification and
## `/dev-story`'s run-and-observe screenshots (story 035's Migration Plan
## Step 2 rewrite; ADR-0004 Migration item 4) -- rewritten, not deleted, from
## the pre-Game-State `ChapterFlow` demo this replaces. Not part of the
## shipped game: `run/main_scene` is `game_root.tscn`, never this scene.
##
## Presses New Game immediately, then (debug builds only,
## `OS.is_debug_build()`) auto-resolves every fight before `--stop-at=`'s
## index with `DebugLaunchArgs.force_outcome()` -- no autoplay, so it reaches
## the boss fight the same way a real win would (session memory: "Boss
## balance open question" -- naive autoplay cannot beat it). Holds at the
## `--stop-at=` fight with no action taken, so its just-entered state is what
## is on screen for the screenshot. Forcing `defeat` instead holds on the
## Defeat Prompt it opens, rather than on a fight -- also screenshot-useful.
##
## `--stop-at=<fight index 0-3>` (default 1): 0-2 are the regular fights, 3
## is the boss fight. `--debug-force-outcome=<victory|defeat>` (default
## `victory`) picks what every auto-resolved fight before `--stop-at=` ends in.
##
## Usage example:
## [codeblock]
## godot --path . --windowed --resolution 1280x720 res://src/chapters/chapter_flow_demo.tscn -- --stop-at=1 --debug-force-outcome=victory
## [/codeblock]
extends Control

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"

var _game_root: GameRoot
var _stop_at_fight: int = 1
var _forced_outcome: String = DebugLaunchArgs.VICTORY
var _resolved_fight_count: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--stop-at="):
			_stop_at_fight = int(arg.trim_prefix("--stop-at="))
	var parsed: String = DebugLaunchArgs.parse_forced_outcome(args)
	if parsed != "":
		_forced_outcome = parsed

	_game_root = preload(_GAME_ROOT_SCENE).instantiate()
	add_child(_game_root)
	# New Game is pressed from _process() once Title is idle: in _ready() the
	# Boot -> Title transition is still running, so a request would be busy.


## Polls for an idle Battle fight to auto-resolve. A forced DEFEAT opens the
## Defeat Prompt and does not retry -- `_resolved_fight_count` still
## advances, so the demo holds there instead of on the next fight, which is
## exactly the screenshot a forced defeat is asking for.
func _process(_delta: float) -> void:
	if _game_root == null or _game_root.machine == null:
		return
	if _game_root.machine.phase != GameStateMachine.Phase.IDLE:
		return
	if _game_root.machine.current_mode == GameStateMachine.Mode.TITLE:
		_game_root.machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)
		return
	if _game_root.machine.current_mode != GameStateMachine.Mode.BATTLE:
		return
	if _resolved_fight_count >= _stop_at_fight:
		return  # Hold here -- this is the fight the screenshot should land on.
	var battle_mode: BattleMode = _game_root.current_mode_node() as BattleMode
	if battle_mode == null or battle_mode.battle == null:
		return
	DebugLaunchArgs.force_outcome(battle_mode.battle, _forced_outcome)
	if _forced_outcome == DebugLaunchArgs.VICTORY:
		_game_root.machine.report_results_done()
	_resolved_fight_count += 1
