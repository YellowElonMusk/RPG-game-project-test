## Builds today's runtime `Move` from a `MoveData` record (content-migration
## story 023; ADR-0001 EffectDescriptor adapter, Migration Step 3; ADR-0010
## §8). Pure and static: it reads the record's values, copies them into a new
## `Move` and never keeps the record. `BattleCore` never sees a record.
##
## One `match` maps the record's single EffectDescriptor `type` to one
## category/effect pair (ADR-0010 §8: a new effect type means a new enum
## value, a new arm, a new registration and a test). An unregistered type, an
## unknown `target_type`, or a record with other than one descriptor is an
## error (`push_error`, `null`), never a silent `NONE`.
##
## Usage example:
## [codeblock]
## var late_fee: Move = MoveAdapter.from_catalog(BattleCatalog.shipped(), "move_late_fee")
## [/codeblock]
class_name MoveAdapter
extends RefCounted


## A new `Move` copied from `record`, or `null` with a `push_error`.
## Example: [code]var move := MoveAdapter.from_record(record as MoveData)[/code]
static func from_record(record: MoveData) -> Move:
	if record == null:
		push_error("MoveAdapter.from_record: null record.")
		return null
	if record.effects.size() != 1:
		push_error("MoveAdapter.from_record(%s): %d effect descriptors; a runtime Move holds exactly one." % [
				record.id, record.effects.size()])
		return null
	var target: int = _target_type(record.target_type)
	if target < 0:
		push_error("MoveAdapter.from_record(%s): unknown target_type '%s'." % [record.id, record.target_type])
		return null
	var effect: Dictionary = record.effects[0]
	var effect_type: String = str(effect.get("type", ""))
	var power: int = int(effect.get("power", 0))
	var category: Move.Category = Move.Category.SPECIAL
	var special: Move.SpecialEffect = Move.SpecialEffect.NONE
	var rounds: int = 0
	match effect_type:
		"damage":
			category = Move.Category.ATTACK
		"stun":
			special = Move.SpecialEffect.STUN
			power = 0
		"heal_party":
			special = Move.SpecialEffect.HEAL_PARTY
		"heal_single":
			special = Move.SpecialEffect.HEAL_SINGLE
		"damage_debuff":
			special = Move.SpecialEffect.DAMAGE_DEBUFF
			power = 0
			rounds = int(effect.get("rounds", 0))
		"direct_damage":
			special = Move.SpecialEffect.DIRECT_DAMAGE
		_:
			push_error("MoveAdapter.from_record(%s): unregistered effect type '%s'." % [record.id, effect_type])
			return null
	return Move.new(record.display_name, category, record.cost, power,
			target as Move.TargetType, special, rounds)


## Looks `id` up in `catalog` and adapts it. `null` with a `push_error` when
## the catalog is not READY or the id is missing; never a fallback.
## Example: [code]var move := MoveAdapter.from_catalog(catalog, "move_home_run")[/code]
static func from_catalog(catalog: ContentCatalogService, id: String) -> Move:
	if catalog == null:
		push_error("MoveAdapter.from_catalog(%s): no catalog." % id)
		return null
	var record: MoveData = catalog.get_record(&"move", id) as MoveData
	if record == null:
		push_error("MoveAdapter.from_catalog(%s): lookup failed (%s)." % [id, catalog.last_lookup_error])
		return null
	return from_record(record)


# `target_type` string -> `Move.TargetType`, or -1 when unknown.
static func _target_type(value: String) -> int:
	match value:
		"self":
			return Move.TargetType.SELF
		"single_enemy":
			return Move.TargetType.SINGLE_ENEMY
		"single_ally":
			return Move.TargetType.SINGLE_ALLY
		_:
			return -1
