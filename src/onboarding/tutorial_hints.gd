## Onboarding & Tutorial (systems index #21; 2026-11-04, rigor minimal):
## which one-time hints are still due. A hint is "seen" once shown (or once
## the player did what it teaches), stored as the story flag `hint:<id>` in
## `WorldState`, so it is saved with the game and never repeats. The
## Settings toggle `tutorial_hints` (default On) silences every hint without
## marking any seen.
##
## Usage example:
## [codeblock]
## var hints := TutorialHints.new(world_state, func() -> bool: return true)
## if hints.is_due(TutorialHints.FIRST_BATTLE):
##     show_card(TutorialHints.FIRST_BATTLE_TITLE, TutorialHints.FIRST_BATTLE_TEXT)
##     hints.mark_seen(TutorialHints.FIRST_BATTLE)
## [/codeblock]
class_name TutorialHints
extends RefCounted

## Flag prefix in `WorldState`.
const PREFIX: String = "hint:"

## Overworld controls strip, one part each (dismissed by doing it).
const MOVE: String = "move"
const TALK: String = "talk"
const MENU: String = "menu"
const CONTROLS: Array[String] = [MOVE, TALK, MENU]
## First symbol near the squad.
const SYMBOLS: String = "symbols"
## First camp prompt.
const CAMP: String = "camp"
## First visit to the camp screen: setting out saves.
const SAVE: String = "save"
## First battle's how-to card.
const FIRST_BATTLE: String = "first_battle"

const SYMBOLS_TEXT: String = "Touch a patrolling alien to fight. If it spots you, it chases."
const CAMP_TEXT: String = "A café is a camp: rest here to put the squad back on its feet."
const SAVE_TEXT: String = "Tip: setting out from camp saves your game."
const FIRST_BATTLE_TITLE: String = "How to fight"
const FIRST_BATTLE_TEXT: String = "Pick a command for each squad member, then a target.\nDefend halves the damage you take that round.\nSpecials cost MP. Items cost nothing but the item."

## Reads the player's `tutorial_hints` setting; `true` when unset.
var _enabled: Callable = Callable()
var _world: WorldState = null


func _init(world: WorldState, enabled: Callable = Callable()) -> void:
	_world = world
	_enabled = enabled


## `true` while hints are switched on in Settings.
func enabled() -> bool:
	return not _enabled.is_valid() or bool(_enabled.call())


## `true` when hint `id` should show now: hints on and not seen yet.
func is_due(id: String) -> bool:
	return enabled() and _world != null and not _world.has_flag(PREFIX + id)


## Records hint `id` as seen (saved with the game). Ignored while hints are
## off, so switching them back on shows what was skipped.
func mark_seen(id: String) -> void:
	if enabled() and _world != null:
		_world.set_flag(PREFIX + id)


## The rule card's hint id for a faction (once per faction).
static func rule_id(faction_id: String) -> String:
	return "rule_" + faction_id


## The overworld controls strip for what is still due, e.g.
## "[WASD] Move   [Enter] Talk   [Escape] Menu", or "" when all are seen.
func controls_text(glyphs: PromptGlyphs) -> String:
	var parts: PackedStringArray = []
	if is_due(MOVE):
		parts.append("[%s] Move" % move_label(glyphs))
	if is_due(TALK):
		parts.append("[%s] Talk / check" % _label(glyphs, InputActions.CONFIRM))
	if is_due(MENU):
		parts.append("[%s] Menu" % _label(glyphs, InputActions.MENU))
	return "   ".join(parts)


## "WASD" on a keyboard (the first key of each direction), "Left stick" on a
## pad.
static func move_label(glyphs: PromptGlyphs) -> String:
	if glyphs == null:
		return "WASD"
	if glyphs.device == PromptGlyphs.DEVICE_PAD:
		return "Left stick"
	var keys: String = ""
	for action: StringName in [InputActions.MOVE_UP, InputActions.MOVE_LEFT,
			InputActions.MOVE_DOWN, InputActions.MOVE_RIGHT]:
		keys += glyphs.label(action)
	return keys


## The label for `action`, or a plain fallback with no glyphs.
static func _label(glyphs: PromptGlyphs, action: StringName) -> String:
	if glyphs == null:
		return {InputActions.CONFIRM: "Enter", InputActions.MENU: "Escape"}.get(action, String(action))
	return glyphs.label(action)
