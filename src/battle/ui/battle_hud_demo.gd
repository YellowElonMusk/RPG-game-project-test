## Launches a BattleCore + BattleHud with no menu or clicking in front of it,
## so every state Story 005's evidence requires is reachable straight from a
## `godot ... res://....tscn` invocation. Reads `--state=` (and an optional
## `--faction=` override) from OS.get_cmdline_user_args(), mirroring
## prototypes/battle-concept/battle.gd's `--faction=`/`--autoplay` pattern —
## reimplemented fresh, not imported, per `.claude/rules/prototype-code.md`.
## Not part of the shipped game: this is `/dev-story`'s run-and-observe
## scaffold for Story 005's screenshots (`.claude/docs/run-and-observe.md`).
##
## `--state=` values:
## - `normal` (default): a fresh Bureaucratia battle, round 1, with one
##   Attack already submitted so a floating damage number is mid-animation.
## - `permit_pending`: a fresh Bureaucratia battle, round 1 — the permit
##   countdown banner.
## - `permit_granted`: a Bureaucratia battle with round_number forced past
##   BureaucratiaRule.PERMIT_ROUNDS — the "all-out war" banner.
## - `billing`: a fresh MegaCorp battle — the subscription billing banner.
## - `knockout`: a battle with one squad member's HP forced to 0 — the
##   knocked-out card state.
##
## `--faction=bureaucratia|megacorp` overrides the state's default faction
## (every state but `billing` defaults to Bureaucratia).
##
## Usage example:
## [codeblock]
## godot --path . --windowed --resolution 1280x720 res://src/battle/ui/battle_hud_demo.tscn -- --state=permit_granted
## [/codeblock]
extends Control

const SQUAD_HP: int = 30
const SQUAD_MP: int = 10
const SQUAD_ATTACK: int = 12
const SQUAD_DEFENSE: int = 8
const SQUAD_SPEED: int = 10

var _battle: BattleCore
var _hud: BattleHud


func _ready() -> void:
	# Harness scene: boots the shipped catalog the factories read (content-migration
	# story 024; ADR-0004 harness allowance). A no-op once booted.
	ContentBootstrap.run(BattleCatalog.shipped())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var args: PackedStringArray = OS.get_cmdline_user_args()

	var state: String = "normal"
	for arg in args:
		if arg.begins_with("--state="):
			state = arg.trim_prefix("--state=")

	var faction_name: String = "megacorp" if state == "billing" else "bureaucratia"
	for arg in args:
		if arg.begins_with("--faction="):
			faction_name = arg.trim_prefix("--faction=")

	var squad: Array[Combatant] = [
		Combatant.new("Hero A", SQUAD_HP, SQUAD_MP, SQUAD_ATTACK, SQUAD_DEFENSE, SQUAD_SPEED, false),
		Combatant.new("Hero B", SQUAD_HP, SQUAD_MP, SQUAD_ATTACK, SQUAD_DEFENSE, SQUAD_SPEED, false),
	]
	var enemies: Array[Combatant]
	var rule: FactionRule
	if faction_name == "megacorp":
		enemies = [
			MegaCorpRule.make_security_drone(),
			MegaCorpRule.make_middle_manager(),
			MegaCorpRule.make_ceo(),
		]
		rule = MegaCorpRule.new()
	else:
		enemies = [
			BureaucratiaRule.make_clerk(),
			BureaucratiaRule.make_clerk(),
			BureaucratiaRule.make_supervisor(),
		]
		rule = BureaucratiaRule.new()

	_battle = BattleCore.new(squad, enemies, null, rule)
	_hud = preload("res://src/battle/ui/battle_hud.tscn").instantiate()
	add_child(_hud)
	_hud.setup(_battle)
	_battle.start_battle()

	match state:
		"permit_granted":
			_battle.round_number = BureaucratiaRule.PERMIT_ROUNDS + 1
		"knockout":
			_battle.get_living_squad()[0].take_damage(9999)
		"normal":
			# Wait for a layout pass before acting: a freshly-added Control's
			# global_position/size are not valid until Godot has run at least
			# one idle/sort pass, which only happens after _ready() returns.
			# Submitting the attack synchronously here (as the other states
			# do for their own state-setting) would make BattleHud's floating
			# number compute its position from a not-yet-laid-out panel rect
			# and spawn off-screen. Two frames is a safe margin for
			# container sort to settle.
			await get_tree().process_frame
			await get_tree().process_frame
			var living_enemies: Array[Combatant] = _battle.get_living_enemies()
			if not living_enemies.is_empty():
				_battle.submit_action(Move.make_attack(), living_enemies[0])
		_:
			pass  # permit_pending / billing: the fresh round-1 state is the shot.

	_hud.refresh()
