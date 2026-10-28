## Debug-build-only launch-argument helpers (QA RC-6; this story's
## Implementation Notes). Every entry point here is a no-op outside a debug
## build (`OS.is_debug_build()`), so a shipped build never reaches any of
## this. They exist to make QA Check 3's four scripted fights (and story
## 038's screenshots) reachable without autoplay -- naive autoplay cannot
## beat the Bureaucratia boss, and that balance question stays out of this
## gate (session memory: "Boss balance open question").
##
## Usage example:
## [codeblock]
## var battle: BattleCore = battle_mode.battle
## DebugLaunchArgs.force_outcome(battle, DebugLaunchArgs.VICTORY)
## [/codeblock]
class_name DebugLaunchArgs
extends RefCounted

const FORCE_OUTCOME_PREFIX: String = "--debug-force-outcome="
const RETREAT_DESCRIPTOR_FLAG: String = "--debug-retreat-descriptor"
const VICTORY: String = "victory"
const DEFEAT: String = "defeat"

## Debug-build-only placeholder camp id `apply_retreat_override()` registers.
const DEBUG_CAMP_ID: String = "camp_debug_retreat"


## The forced outcome `args` names (`"victory"` / `"defeat"`), or `""` when
## absent, malformed, or not a debug build. Pure beyond the
## `OS.is_debug_build()` guard, so a test can pass a literal array.
static func parse_forced_outcome(args: PackedStringArray) -> String:
	if not OS.is_debug_build():
		return ""
	for arg: String in args:
		if arg.begins_with(FORCE_OUTCOME_PREFIX):
			var value: String = arg.trim_prefix(FORCE_OUTCOME_PREFIX)
			if value == VICTORY or value == DEFEAT:
				return value
	return ""


## Forces `battle`'s outcome deterministically, regardless of roster
## strength (so it reaches a win against the boss too): zeroes the losing
## side's hp directly, then resolves one harmless `Defend` so `BattleCore`'s
## own end-of-move check (`_check_battle_end()`, run unconditionally after
## every resolved move) reports the forced result through the normal
## `battle_ended` signal. A no-op outside a debug build, outside
## `SQUAD_TURN`, or for any `outcome` other than `VICTORY`/`DEFEAT`.
static func force_outcome(battle: BattleCore, outcome: String) -> void:
	if not OS.is_debug_build():
		return
	if battle == null or battle.state != BattleCore.State.SQUAD_TURN:
		return
	match outcome:
		VICTORY:
			for enemy: Combatant in battle.enemies:
				enemy.hp = 0
		DEFEAT:
			for member: Combatant in battle.squad:
				member.hp = 0
		_:
			return
	battle.submit_action(Move.make_defend(), null)


## `true` when `--debug-retreat-descriptor` is present and this is a debug
## build.
static func wants_retreat_descriptor(args: PackedStringArray) -> bool:
	return OS.is_debug_build() and args.has(RETREAT_DESCRIPTOR_FLAG)


## Debug-build-only override for an `EncounterDescriptor` (story 038's
## reachability note): sets `retreat_allowed = true` and registers
## `DEBUG_CAMP_ID` with `machine` so `choose_retreat()`'s payload has
## somewhere to send the player. The caller must already be in `OVERWORLD`,
## idle, with no overlay open (`GameStateMachine.register_camp()`'s own
## gate) -- a no-op outside a debug build.
static func apply_retreat_override(descriptor: EncounterDescriptor, machine: GameStateMachine) -> void:
	if not OS.is_debug_build():
		return
	descriptor.retreat_allowed = true
	machine.register_camp(DEBUG_CAMP_ID)
