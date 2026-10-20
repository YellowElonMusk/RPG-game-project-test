## Launches a ChapterFlow + BattleHud with no menu or clicking in front of
## it, so Story 006's fight-to-fight sequence is reachable straight from a
## `godot ... res://....tscn` invocation, mirroring
## `src/battle/ui/battle_hud_demo.gd`'s shape. Not part of the shipped game:
## this is `/dev-story`'s run-and-observe scaffold for Story 006's
## screenshots (`.claude/docs/run-and-observe.md`).
##
## Auto-resolves every fight before `--stop-at=`'s fight index by repeatedly
## submitting Move.make_attack() against the first living enemy (the same
## idea as the prototype's old `--autoplay`, reimplemented fresh per
## `.claude/rules/prototype-code.md`), then holds at the start of the
## `--stop-at=` fight — no combat is run in that fight — so its just-started
## state (carried-over HP/MP, or the boss roster) is what's on screen for the
## screenshot.
##
## `--faction=bureaucratia|megacorp` (default bureaucratia).
## `--stop-at=<fight index 0-3>` (default 1): 0-2 are the regular fights, 3
## is the boss fight.
##
## Usage example:
## [codeblock]
## godot --path . --windowed --resolution 1280x720 res://src/chapters/chapter_flow_demo.tscn -- --faction=bureaucratia --stop-at=1
## [/codeblock]
extends Control

const SQUAD_HP: int = 30
const SQUAD_MP: int = 10
const SQUAD_ATTACK: int = 12
const SQUAD_DEFENSE: int = 8
const SQUAD_SPEED: int = 10

## Safety cap on fight_started emissions (fresh fights plus retries). Autoplay
## always-attack-first-enemy is expected to win comfortably within a handful
## of rounds per fight; this only guards the demo process against an
## unbounded loss->retry recursion rather than ever being expected to trigger.
const MAX_FIGHT_STARTS: int = 30

var _hud: BattleHud
var _chapter: ChapterFlow
var _stop_at_fight: int = 1
var _fight_start_count: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var args: PackedStringArray = OS.get_cmdline_user_args()

	var faction_name: String = ChapterFlow.FACTION_BUREAUCRATIA
	for arg in args:
		if arg.begins_with("--faction="):
			faction_name = arg.trim_prefix("--faction=")
	for arg in args:
		if arg.begins_with("--stop-at="):
			_stop_at_fight = int(arg.trim_prefix("--stop-at="))

	var squad: Array[Combatant] = [
		Combatant.new("Hero A", SQUAD_HP, SQUAD_MP, SQUAD_ATTACK, SQUAD_DEFENSE, SQUAD_SPEED, false),
		Combatant.new("Hero B", SQUAD_HP, SQUAD_MP, SQUAD_ATTACK, SQUAD_DEFENSE, SQUAD_SPEED, false),
	]

	_hud = preload("res://src/battle/ui/battle_hud.tscn").instantiate()
	add_child(_hud)

	_chapter = ChapterFlow.new(faction_name, squad)
	_chapter.fight_started.connect(_on_fight_started)
	_chapter.chapter_won.connect(_on_chapter_won)
	_chapter.start_chapter()


func _on_fight_started(battle: BattleCore, fight_index: int, _is_boss: bool) -> void:
	_fight_start_count += 1
	_hud.setup(battle)
	if _fight_start_count > MAX_FIGHT_STARTS:
		push_error("ChapterFlowDemo: exceeded %d fight_started events, stopping autoplay" % MAX_FIGHT_STARTS)
		return
	if fight_index < _stop_at_fight:
		_autoplay(battle)
	# else: hold here — this is the fight the screenshot should land on.


## Resolves `battle` by always Attacking the first living enemy until it
## ends. A loss/advance inside submit_action() re-enters _on_fight_started()
## synchronously (ChapterFlow's battle_ended handler runs inline), which
## drives the new BattleCore from its own fresh call frame; this loop's own
## `battle` reference is then a finished (WON/LOST) battle, so its while
## condition simply falls through once control returns here.
func _autoplay(battle: BattleCore) -> void:
	while battle.state == BattleCore.State.SQUAD_TURN:
		var living_enemies: Array[Combatant] = battle.get_living_enemies()
		if living_enemies.is_empty():
			break
		battle.submit_action(Move.make_attack(), living_enemies[0])
	_hud.refresh()


func _on_chapter_won() -> void:
	_hud.refresh()
