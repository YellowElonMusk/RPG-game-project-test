## Default focus for the four guarded screens (GDD rule 9; story 058). Pure
## lookups each screen's caller applies when it opens.
class_name MenuDefaultFocus
extends RefCounted

## The command id the command menu falls back to.
const ATTACK: StringName = &"attack"
## The Defeat Prompt's default option (the cheapest mistake).
const DEFEAT_PROMPT: StringName = &"retry"
## The results screen's one continue option.
const RESULTS: StringName = &"continue"


## The screens on which `MenuGuard` is required (ADR-0008 §6).
static func guarded_screens() -> Array[StringName]:
	return [&"command_menu", &"target_selection", &"defeat_prompt", &"results"]


## The member's `last_used` command if it is in `commands`, available and
## costs no MP, else `ATTACK`. `commands`: id -> `{"available": bool, "mp_cost": int}`.
static func command_menu(last_used: StringName, commands: Dictionary) -> StringName:
	var entry: Variant = commands.get(last_used)
	if entry is Dictionary and bool(entry.get("available", false)) \
			and int(entry.get("mp_cost", 0)) == 0:
		return last_used
	return ATTACK


## The index of the first living target, or -1 if none lives.
static func target_selection(alive: Array) -> int:
	for i: int in alive.size():
		if bool(alive[i]):
			return i
	return -1
