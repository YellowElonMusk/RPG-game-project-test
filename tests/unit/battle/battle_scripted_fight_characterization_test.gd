## Story 008 (ADR-0001 Migration Step 0; ADR-0007 "for whole battles"; ADR-0010
## Migration Step 1): pins two whole scripted fights -- the fixture squad
## against each faction's shipped roster, under the shipped rule, driven by
## `ScriptedFightCommands.BUREAUCRATIA`/`MEGACORP` through
## `BattleCore.submit_action()` -- end to end: the resolved log, every
## combatant's hp/mp after each resolved action, the signal order, the
## number of script commands consumed, the result and the final `rng.state`.
## Both fights lose: the shipped squad cannot beat either boss at these stat
## blocks (the open balance question this epic does not resolve), and that
## loss is what `CharacterizationExpected.BUREAUCRATIA_FIGHT`/`MEGACORP_FIGHT`
## pin, not a "fixed" win. Pinned values are literal copies read once from
## today's code, built only through `BattleContentSeam` and
## `BattleContentSeam.arrange_vitals`.
extends GdUnitTestSuite

const _SQUAD_KEYS: Array[String] = ["karen", "chef", "florida_man", "baguette_thrower"]


func _squad_member(key: String) -> Combatant:
	var block: Dictionary
	match key:
		"karen": block = CharacterizationExpected.SQUAD_KAREN
		"chef": block = CharacterizationExpected.SQUAD_CHEF
		"florida_man": block = CharacterizationExpected.SQUAD_FLORIDA_MAN
		"baguette_thrower": block = CharacterizationExpected.SQUAD_BAGUETTE_THROWER
	return Combatant.new(block["name"], block["max_hp"], block["max_mp"],
			block["attack"], block["defense"], block["speed"], false)


func _fixture_squad() -> Array[Combatant]:
	var squad: Array[Combatant] = []
	for key: String in _SQUAD_KEYS:
		squad.append(_squad_member(key))
	return squad


func _move_for(id: String) -> Move:
	match id:
		"attack": return Move.make_attack()
		"defend": return Move.make_defend()
		_: return BattleContentSeam.move(id)


## Resolves `command`'s target against the CURRENT living roster at submit
## time (`min(target_index, living.size() - 1)`), per the story's own rule;
## ignored for a `SELF`/Defend move.
func _submit_command(battle: BattleCore, command: Dictionary) -> BattleOutcome:
	var move: Move = _move_for(command["move_id"])
	var target: Combatant = null
	if move.target_type == Move.TargetType.SINGLE_ENEMY:
		var living: Array[Combatant] = battle.get_living_enemies()
		target = living[mini(command["target_index"], living.size() - 1)]
	elif move.target_type == Move.TargetType.SINGLE_ALLY:
		var living: Array[Combatant] = battle.get_living_squad()
		target = living[mini(command["target_index"], living.size() - 1)]
	return battle.submit_action(move, target)


## Runs one scripted fight to `battle_ended` or `ROUND_CAP`, recording the
## same four artifacts the fixture pins: `commands_consumed`, the signal
## order as one letter per emission (T/A/R/E), and, via `action_resolved`,
## a `[hp, mp]` snapshot of the whole roster alongside each resolved entry.
func _run_fight(enemies: Array[Combatant], rule: FactionRule, seed_value: int,
		script: Array[Dictionary], florida_mp_override: int) -> Dictionary:
	var squad := _fixture_squad()
	var roster: Array[Combatant] = squad + enemies
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var battle := BattleCore.new(squad, enemies, rng, rule)

	var signal_box: Array = [""]  # [codes] -- String, like bool, is not reference-captured by a lambda
	var hp_snapshots: Array = []
	var ended_box: Array = [false, false]  # [ended, won]
	battle.turn_started.connect(func(_c): signal_box[0] += "T")
	battle.action_resolved.connect(func(_o):
		signal_box[0] += "A"
		var row: Array = []
		for c: Combatant in roster:
			row.append([c.hp, c.mp])
		hp_snapshots.append(row))
	battle.round_advanced.connect(func(_r): signal_box[0] += "R")
	battle.battle_ended.connect(func(w): signal_box[0] += "E"; ended_box[0] = true; ended_box[1] = w)

	battle.start_battle()
	if florida_mp_override >= 0:
		BattleContentSeam.arrange_vitals(squad[2], squad[2].max_hp, florida_mp_override)

	var cursor := 0
	while cursor < script.size():
		if battle.state == BattleCore.State.WON or battle.state == BattleCore.State.LOST:
			break
		if battle.round_number > CharacterizationExpected.ROUND_CAP:
			break
		_submit_command(battle, script[cursor])
		cursor += 1

	return {
		"battle": battle, "roster": roster, "commands_consumed": cursor,
		"ended": ended_box[0], "won": ended_box[1], "signal_codes": signal_box[0],
		"hp_snapshots": hp_snapshots,
	}


func _assert_fight_matches(result: Dictionary, pin: Dictionary, label: String) -> void:
	var battle: BattleCore = result["battle"]
	var roster: Array[Combatant] = result["roster"]

	assert_bool(result["ended"]).override_failure_message("%s: battle_ended must fire" % label).is_true()
	assert_int(result["commands_consumed"]).override_failure_message("%s commands_consumed" % label).is_equal(pin["commands_consumed"])
	assert_bool(result["won"]).override_failure_message("%s won" % label).is_equal(pin["won"])
	assert_int(battle.round_number).override_failure_message("%s final_round" % label).is_equal(pin["final_round"])
	assert_int(battle.rng.state).override_failure_message("%s rng_state" % label).is_equal(pin["rng_state"])
	assert_str(result["signal_codes"]).override_failure_message("%s signal_log" % label).is_equal(pin["signal_log_codes"])

	var resolved_log: Array = BattleContentSeam.resolved_log(battle)
	var pinned_log: Array = pin["resolved_log"]
	assert_int(resolved_log.size()).override_failure_message("%s resolved_log size" % label).is_equal(pinned_log.size())
	for i: int in mini(resolved_log.size(), pinned_log.size()):
		var entry: Dictionary = resolved_log[i]
		var pinned: Dictionary = pinned_log[i]
		var entry_label: String = "%s resolved_log[%d]" % [label, i]
		assert_int(roster.find(entry["actor"])).override_failure_message("%s actor" % entry_label).is_equal(pinned["actor"])
		assert_str(entry["move_name"]).override_failure_message("%s move_name" % entry_label).is_equal(pinned["move_name"])
		assert_int(entry["category"]).override_failure_message("%s category" % entry_label).is_equal(pinned["category"])
		var target_index: int = roster.find(entry["target"]) if entry["target"] != null else -1
		var pinned_target: int = pinned["target"] if pinned["target"] != null else -1
		assert_int(target_index).override_failure_message("%s target" % entry_label).is_equal(pinned_target)
		assert_int(entry["hp_delta"]).override_failure_message("%s hp_delta" % entry_label).is_equal(pinned["hp_delta"])
		assert_int(entry["mp_delta"]).override_failure_message("%s mp_delta" % entry_label).is_equal(pinned["mp_delta"])
		assert_bool(entry["target_knocked_out"]).override_failure_message("%s target_knocked_out" % entry_label).is_equal(pinned["target_knocked_out"])
		assert_int(entry["round_number"]).override_failure_message("%s round_number" % entry_label).is_equal(pinned["round_number"])

	var pinned_snapshots: Array = pin["hp_snapshots"]
	assert_int(result["hp_snapshots"].size()).override_failure_message("%s hp_snapshots size" % label).is_equal(pinned_snapshots.size())
	for i: int in mini(result["hp_snapshots"].size(), pinned_snapshots.size()):
		assert_array(result["hp_snapshots"][i]).override_failure_message(
				"%s hp_snapshots[%d]" % [label, i]).is_equal(pinned_snapshots[i])


# --- Test: Bureaucratia fight ---

func test_bureaucratia_scripted_fight_equals_the_pin() -> void:
	var enemies: Array[Combatant] = [
		BattleContentSeam.enemy("enemy_clerk"), BattleContentSeam.enemy("enemy_clerk"),
		BattleContentSeam.enemy("enemy_supervisor"),
	]
	var rule: FactionRule = BattleContentSeam.rule("rule_bureaucratia_permit")
	var result: Dictionary = _run_fight(enemies, rule, CharacterizationExpected.SEED_FIGHT_B,
			ScriptedFightCommands.BUREAUCRATIA, -1)
	_assert_fight_matches(result, CharacterizationExpected.BUREAUCRATIA_FIGHT, "Bureaucratia")


# --- Test: MegaCorp fight ---

func test_megacorp_scripted_fight_equals_the_pin() -> void:
	var enemies: Array[Combatant] = [
		BattleContentSeam.enemy("enemy_security_drone"), BattleContentSeam.enemy("enemy_middle_manager"),
		BattleContentSeam.enemy("enemy_ceo"),
	]
	var rule: FactionRule = BattleContentSeam.rule("rule_megacorp_billing")
	var result: Dictionary = _run_fight(enemies, rule, CharacterizationExpected.SEED_FIGHT_M,
			ScriptedFightCommands.MEGACORP, 4)
	_assert_fight_matches(result, CharacterizationExpected.MEGACORP_FIGHT, "MegaCorp")


# --- Test: carryover ---

## `start_battle(false)` carries the squad's current hp/mp into a second
## fight (a knocked-out member stays knocked out and is skipped for the
## first turn; a damaged member keeps its hp/mp) while enemies are still
## fully reset; the second fight is then played out (every turn an Attack on
## the first living enemy) and its result pinned
## (`CharacterizationExpected.CARRYOVER_FIGHT`).
func test_carryover_start_battle_false_skips_knocked_out_member() -> void:
	var pin: Dictionary = CharacterizationExpected.CARRYOVER_FIGHT
	var squad := _fixture_squad()
	var enemies: Array[Combatant] = [
		BattleContentSeam.enemy("enemy_clerk"), BattleContentSeam.enemy("enemy_clerk"),
		BattleContentSeam.enemy("enemy_supervisor"),
	]
	var rule: FactionRule = BattleContentSeam.rule("rule_bureaucratia_permit")
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.SEED_FIGHT_B
	var battle := BattleCore.new(squad, enemies, rng, rule)
	var ended_box: Array = [false, false]  # [ended, won]
	battle.battle_ended.connect(func(w): ended_box[0] = true; ended_box[1] = w)
	battle.start_battle()

	# The end vitals of a prior fight: Karen (squad[0]) knocked out, Chef
	# (squad[1]) damaged and low on MP, and a damaged enemy that must reset.
	BattleContentSeam.arrange_vitals(squad[0], 0, 0)
	BattleContentSeam.arrange_vitals(squad[1], pin["chef_hp"], pin["chef_mp"])
	BattleContentSeam.arrange_vitals(enemies[0], 1, 0)

	battle.start_battle(false)

	assert_bool(squad[0].is_knocked_out()).override_failure_message("Karen stays knocked out").is_true()
	assert_int(squad[1].hp).override_failure_message("Chef's hp carries over").is_equal(pin["chef_hp"])
	assert_int(squad[1].mp).override_failure_message("Chef's mp carries over").is_equal(pin["chef_mp"])
	assert_object(battle.get_active_combatant()).override_failure_message(
			"the first turn skips the knocked-out member").is_same(squad[1])
	assert_int(battle.round_number).is_equal(1)
	for i: int in enemies.size():
		assert_int(enemies[i].hp).override_failure_message(
				"enemy %d is fully reset" % i).is_equal(enemies[i].max_hp)

	var cursor := 0
	while cursor < CharacterizationExpected.ROUND_CAP * 4:
		if battle.state == BattleCore.State.WON or battle.state == BattleCore.State.LOST:
			break
		if battle.round_number > CharacterizationExpected.ROUND_CAP:
			break
		battle.submit_action(Move.make_attack(), battle.get_living_enemies()[0])
		cursor += 1

	assert_bool(ended_box[0]).override_failure_message("carryover battle_ended must fire").is_true()
	assert_int(cursor).override_failure_message("carryover commands_consumed").is_equal(pin["commands_consumed"])
	assert_bool(ended_box[1]).override_failure_message("carryover won").is_equal(pin["won"])
	assert_int(battle.round_number).override_failure_message("carryover final_round").is_equal(pin["final_round"])
	assert_int(rng.state).override_failure_message("carryover rng_state").is_equal(pin["rng_state"])
	assert_int(battle.outcome_log.size()).override_failure_message("carryover outcome_log size").is_equal(pin["outcome_log_size"])
