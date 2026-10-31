## The one seam every content-migration characterization test builds content
## through (ADR-0001 Migration Step 0; ADR-0011 Migration Step 1). Three later
## API changes would otherwise break every test that calls today's battle API
## directly: ADR-0011 deletes the `make_*()` factories and `is_manager()`;
## ADR-0011 changes `choose_enemy_action()`'s return shape from `Array` of
## `{"move","target"}` to `Array[EnemyAction]`; ADR-0007 deletes the heal
## helpers and `DamageCalculator` and makes `Combatant.hp` read-only. A
## characterization test asks this seam for content by its *future* record ID
## (never a factory call, never `display_name`) and reads effects only
## through `BattleCore` or this seam's own helpers. When a later migration
## story changes one of those three APIs, it edits this file and nothing else
## (story 023 replaced the hand-built named attacks with the catalog
## adapter; story 006/ADR-0007 Step 3 changes `arrange_vitals()` to
## call `restore_vitals()`; ADR-0011 Step 2 changes `enemy_turn()`'s read of
## `choose_enemy_action()`'s return value).
##
## This file lives under `tests/`, so it is not shipped and is not covered by
## the content lint (story 035).
##
## Usage example:
## [codeblock]
## var clerk: Combatant = BattleContentSeam.enemy("enemy_clerk")
## var rule: FactionRule = BattleContentSeam.rule("rule_bureaucratia_permit")
## var turn: Array = BattleContentSeam.enemy_turn(rule, clerk, squad, 1, rng)
## [/codeblock]
class_name BattleContentSeam
extends RefCounted

## Story 023/024: every seam builder first boots the shipped catalog once per
## test process (`ensure_catalog()`), because the factories and both rules'
## named attacks now read their records from it. `_static_init()` does the
## same the moment any test script referencing this seam is loaded, so a
## characterization test that calls a factory directly before any seam
## builder (story 006's) still finds the catalog READY.
static func _static_init() -> void:
	ensure_catalog()


## Runs `ContentBootstrap.run()` on the `ContentCatalog` autoload against
## `res://data`; a no-op once the catalog is not UNLOADED. A test-harness
## call (the allowance ADR-0004 gives harness scenes), never production
## lazy-loading: production factories never trigger a load and fail loudly
## if the catalog isn't READY.
## Example: [code]BattleContentSeam.ensure_catalog()[/code]
static func ensure_catalog() -> void:
	var main_loop: SceneTree = Engine.get_main_loop() as SceneTree
	if main_loop == null or main_loop.root == null or not main_loop.root.has_node(^"ContentCatalog"):
		return
	ContentBootstrap.run(BattleCatalog.shipped())


## Builds the enemy for `id` from today's faction-rule factories (Acceptance
## Criterion). An unknown id fails the calling test.
## Example: [code]var clerk: Combatant = BattleContentSeam.enemy("enemy_clerk")[/code]
static func enemy(id: String) -> Combatant:
	ensure_catalog()
	match id:
		"enemy_clerk": return BureaucratiaRule.make_clerk()
		"enemy_supervisor": return BureaucratiaRule.make_supervisor()
		"enemy_security_drone": return MegaCorpRule.make_security_drone()
		"enemy_middle_manager": return MegaCorpRule.make_middle_manager()
		"enemy_ceo": return MegaCorpRule.make_ceo()
		_:
			_fail_unknown_id("enemy", id)
			return null


## Builds the move for `id`: one of the squad's 5 Specials (built from
## `SquadSpecials`' own factories) or one of the 9 named attacks (built from
## its Move record through `MoveAdapter`, story 023). An unknown id fails the
## calling test.
## Example: [code]var move: Move = BattleContentSeam.move("move_late_fee")[/code]
static func move(id: String) -> Move:
	ensure_catalog()
	match id:
		"move_speak_to_the_manager": return SquadSpecials.make_speak_to_the_manager()
		"move_family_meal": return SquadSpecials.make_family_meal()
		"move_appetizer": return SquadSpecials.make_appetizer()
		"move_viral_stunt": return SquadSpecials.make_viral_stunt()
		"move_home_run": return SquadSpecials.make_home_run()
	var named: Move = MoveAdapter.from_catalog(BattleCatalog.shipped(), id) 			if BattleCatalog.shipped().has_record(&"move", id) else null
	if named == null:
		_fail_unknown_id("move", id)
	return named


## Builds the faction rule for `id`. An unknown id fails the calling test.
## Example: [code]var rule: FactionRule = BattleContentSeam.rule("rule_bureaucratia_permit")[/code]
static func rule(id: String) -> FactionRule:
	ensure_catalog()
	match id:
		"rule_bureaucratia_permit": return BureaucratiaRule.new()
		"rule_megacorp_billing": return MegaCorpRule.new()
		_:
			_fail_unknown_id("rule", id)
			return null


## Today's enemy turn, normalised to a shape every characterization test can
## read without touching `choose_enemy_action()`'s own return shape (today's
## `Array` of `{"move","target"}`; ADR-0011 Step 2 changes it to
## `Array[EnemyAction]` — this function is the one place that edit happens).
## Non-damage actions (the pre-permit Defend) are included with `power 0`.
## Example: [code]var turn := BattleContentSeam.enemy_turn(rule, clerk, squad, 1, rng)[/code]
static func enemy_turn(rule_instance: FactionRule, enemy_combatant: Combatant,
		living_squad: Array[Combatant], round_number: int, rng: RandomNumberGenerator) -> Array:
	var raw: Array = rule_instance.choose_enemy_action(enemy_combatant, living_squad, round_number, rng)
	var normalized: Array = []
	for action: Dictionary in raw:
		var action_move: Move = action.get("move")
		normalized.append({
			"move_name": action_move.display_name,
			"power": action_move.power,
			"target": action.get("target"),
		})
	return normalized


## Sets `c`'s HP and MP directly (RC-1: the seam owns state arrangement).
## Characterization tests change state only through this or through
## `BattleCore`, never by writing `hp` themselves. `hp` above `max_hp` fails
## the calling test. After ADR-0007 Step 3 makes `Combatant.hp` read-only,
## this is the one function that moves to calling `restore_vitals(hp, mp)`.
## Example: [code]BattleContentSeam.arrange_vitals(karen, 17, 0)[/code]
static func arrange_vitals(c: Combatant, hp: int, mp: int) -> void:
	if hp > c.max_hp:
		_fail_unknown_id("arrange_vitals", "hp %d exceeds max_hp %d" % [hp, c.max_hp])
		return
	# heal() clamps to max_hp, so this reaches a known starting point
	# regardless of c's current HP; take_damage() then brings it down to the
	# exact target. spend_mp()'s own clampi(mp - amount, 0, max_mp) already
	# handles a negative amount as an increase, so one call reaches the
	# target MP from either direction.
	c.heal(c.max_hp)
	c.take_damage(c.max_hp - hp)
	c.spend_mp(c.mp - mp)


## Story 008's filtered view of a battle's `outcome_log`: one plain
## Dictionary per entry (`actor`, `move_name`, `category`, `target`,
## `hp_delta`, `mp_delta`, `target_knocked_out`, `round_number`), with any
## non-`RESOLVED` entry dropped. `BattleOutcome` has no `result` field yet
## (ADR-0007 Step 4 adds `NO_TARGET`/`UNAFFORDABLE` log-only entries), so
## `outcome.get("result")` returns `null` today and every entry passes; once
## the field exists, this is the one place that starts filtering, and this
## story's own test does not change.
## Example: [code]var log: Array = BattleContentSeam.resolved_log(battle)[/code]
static func resolved_log(battle: BattleCore) -> Array:
	var filtered: Array = []
	for outcome: BattleOutcome in battle.outcome_log:
		var result_value: Variant = outcome.get("result")
		if result_value != null and result_value != "RESOLVED":
			continue
		filtered.append({
			"actor": outcome.actor,
			"move_name": outcome.move_name,
			"category": outcome.category,
			"target": outcome.target,
			"hp_delta": outcome.hp_delta,
			"mp_delta": outcome.mp_delta,
			"target_knocked_out": outcome.target_knocked_out,
			"round_number": outcome.round_number,
		})
	return filtered


## A `FactionRule` test double (RC-2) that allows every move in every round
## and plays back `script` in order: each entry becomes one enemy action, the
## target read from `living_squad[target_index]`. An entry names its move
## either by `move_id` (built through `move()`, so this seam owns the shape)
## or, for a move `move()` cannot build (story 005: `Move.make_defend()` has
## no record ID), a literal `move` object directly. An empty (or exhausted)
## script yields no enemy actions. Injected through
## `BattleCore._init(..., p_faction_rule)`.
## Example: [code]var rule := BattleContentSeam.scripted_rule([{"move_id": "move_late_fee", "target_index": 1}])[/code]
## Example (literal move): [code]var rule := BattleContentSeam.scripted_rule([{"move": Move.make_defend(), "target_index": 0}])[/code]
static func scripted_rule(script: Array) -> FactionRule:
	ensure_catalog()
	# Move IDs are resolved here, not inside the inner class: an inner class
	# naming its outer script (`BattleContentSeam.move()`) is a script
	# dependency cycle Godot never unloads, and it kept this script -- and the
	# gdUnit4 classes it references -- alive at the exit of every test run.
	var resolved: Array = []
	for entry: Dictionary in script:
		var e: Dictionary = entry.duplicate()
		if not e.has("move"):
			e["move"] = move(e["move_id"])
		resolved.append(e)
	return _ScriptedEnemyRule.new(resolved)


# Fails the calling test: logs to the engine console and reports a gdUnit4
# assertion failure through the same signal every real assert_*() call uses
# (GdAssertReports.report_error() -> gdunit_set_test_failed.emit(true)),
# without depending on any assert "Impl" class directly. This is what makes
# `assert_failure(func(): BattleContentSeam.enemy("enemy_nope")).is_failed()`
# (the story's own QA Test Case) pass.
static func _fail_unknown_id(kind: String, detail: String) -> void:
	var message: String = "BattleContentSeam.%s: unknown id or bad arrangement: %s" % [kind, detail]
	push_error(message)
	GdAssertReports.report_error(GdUnitError.new(message, GdUnitStackTrace.new().get_line_number(), GdUnitStackTrace.new()))


class _ScriptedEnemyRule extends FactionRule:
	var _script: Array
	var _cursor: int = 0


	func _init(script: Array) -> void:
		_script = script


	func specials_allowed(_round_number: int) -> bool:
		return true


	func move_allowed(_actor: Combatant, _move: Move) -> bool:
		return true


	func choose_enemy_action(_enemy: Combatant, living_squad: Array[Combatant],
			_round_number: int, _rng: RandomNumberGenerator) -> Array:
		if _cursor >= _script.size():
			return []
		var entry: Dictionary = _script[_cursor]
		_cursor += 1
		var scripted_move: Move = entry["move"]
		var target: Combatant = living_squad[entry["target_index"]]
		return [{"move": scripted_move, "target": target}]
