## Battle mode's Retry handle (ADR-0002 §7, ADR-0010 §5 "Retry" step 2): the
## party's HP/MP at the moment `capture_start_snapshot()` ran -- immediately
## after `BattleCore` is built and `start_battle(false)` has run, so these are
## whatever that left untouched (the carryover values from the previous
## fight, not a full heal).
##
## Restoring never touches per-fight transients (`is_defending`/`is_stunned`/
## `vulnerable_rounds_left`): those are always cleared, never restored, by
## `BattleCore.clear_transients()` (ADR-0010 §5 step 2 / §7) -- `BattleMode`
## calls that itself, right after `restore_into()`.
##
## Items and the enemy group are not captured here (TODO(items-equipment): items -- no
## inventory system exists yet; enemy group -- needs no snapshot at all,
## because `BattleCore.start_battle()` unconditionally resets every enemy,
## knocked out or not, on every call it makes, including the one Retry makes).
class_name BattleStartSnapshot
extends RefCounted

var party_hp: Array[int] = []
var party_mp: Array[int] = []


## Example: [code]var snapshot := BattleStartSnapshot.capture(party)[/code]
static func capture(party: Array[Combatant]) -> BattleStartSnapshot:
	var snapshot := BattleStartSnapshot.new()
	for combatant: Combatant in party:
		snapshot.party_hp.append(combatant.hp)
		snapshot.party_mp.append(combatant.mp)
	return snapshot


## Restores `party`'s HP/MP in place, by index. `party` must be the same
## array (same order, same size) `capture()` was called with.
## Example: [code]snapshot.restore_into(party)[/code]
func restore_into(party: Array[Combatant]) -> void:
	for i in party.size():
		party[i].hp = party_hp[i]
		party[i].mp = party_mp[i]
