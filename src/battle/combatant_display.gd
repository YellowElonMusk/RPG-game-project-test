## A value copy of one combatant's HUD-visible state at one point in a
## battle replay (ADR-0006 §2 "Display snapshots", Key Interfaces). The HUD
## reads HP, MP, Defend, stun and Viral Stunt only through these copies,
## never `Combatant.hp` directly (GDD sprite-camera-presentation AC-14).
##
## Usage example:
## [codeblock]
## var shown: CombatantDisplay = controller.get_display(karen)
## hp_label.text = str(shown.hp)
## [/codeblock]
class_name CombatantDisplay
extends RefCounted

## HP at the snapshot.
var hp: int = 0
## MP at the snapshot.
var mp: int = 0
## Whether the combatant was defending.
var is_defending: bool = false
## Whether the combatant was stunned.
var is_stunned: bool = false
## Viral Stunt rounds left.
var vulnerable_rounds_left: int = 0


## Reads `c`'s live values into a new copy. Read-only: never writes to `c`.
## Example: [code]var d := CombatantDisplay.from_combatant(c)[/code]
static func from_combatant(c: Combatant) -> CombatantDisplay:
	var d := CombatantDisplay.new()
	d.hp = c.hp
	d.mp = c.mp
	d.is_defending = c.is_defending
	d.is_stunned = c.is_stunned
	d.vulnerable_rounds_left = c.vulnerable_rounds_left
	return d


## Returns an independent copy, so a caller can never edit a held snapshot.
func copy() -> CombatantDisplay:
	var d := CombatantDisplay.new()
	d.hp = hp
	d.mp = mp
	d.is_defending = is_defending
	d.is_stunned = is_stunned
	d.vulnerable_rounds_left = vulnerable_rounds_left
	return d


## True when every field equals `c`'s live value.
func matches(c: Combatant) -> bool:
	return hp == c.hp and mp == c.mp and is_defending == c.is_defending \
			and is_stunned == c.is_stunned and vulnerable_rounds_left == c.vulnerable_rounds_left
