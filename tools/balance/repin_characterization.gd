extends SceneTree
## Deliberate re-pin of the content-migration characterization fixtures after
## a balance change (2026-11-03: the Clerk retuned from 40/11/6 to 28/9/5).
## The pins were "run once and frozen, the generator deleted"; this
## regenerates exactly the values that run produced, using the tests' own
## case runners (loaded from the test scripts, never re-implemented):
##
##   - every DAMAGE_CASES result line, recomputed in place;
##   - BUREAUCRATIA_FIGHT, rebuilt from `_run_fight()`;
##   - CARRYOVER_FIGHT's outcome fields, from the test's own procedure.
##
## It rewrites `tests/unit/battle/fixtures/characterization_expected.gd`
## and prints the specials test's two Clerk-dependent constants. Values that
## do not depend on a changed stat come out unchanged, which is the
## regenerator's own self-check. Headless:
##
##   godot --headless --path . -s res://tools/balance/repin_characterization.gd

const FIXTURE: String = "res://tests/unit/battle/fixtures/characterization_expected.gd"
const DAMAGE_TEST: String = "res://tests/unit/battle/battle_moves_damage_characterization_test.gd"
const FIGHT_TEST: String = "res://tests/unit/battle/battle_scripted_fight_characterization_test.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	BattleContentSeam.ensure_catalog()
	var dmg: Node = (load(DAMAGE_TEST) as GDScript).new()
	var fight: Node = (load(FIGHT_TEST) as GDScript).new()
	var lines: PackedStringArray = FileAccess.get_file_as_string(FIXTURE).split("\n")
	var out: PackedStringArray = []
	var head := RegEx.create_from_string('\\{"(enemy|squad)": "([a-z_]+)", "move": "([a-z_]+)"')
	var res := RegEx.create_from_string('^(\\t+)"([a-z_]+):([a-z]+)": \\[(-?\\d+), (-?\\d+)\\],$')
	var side: String = ""
	var who: String = ""
	var move: String = ""
	var changed: int = 0
	var i: int = 0
	while i < lines.size():
		var line: String = lines[i]
		if line.begins_with("const BUREAUCRATIA_FIGHT: Dictionary = {"):
			var end: int = i + 1
			while not lines[end].begins_with("}"):
				end += 1
			out.append_array(_bureaucratia_block(fight).split("\n"))
			i = end + 1
			continue
		if line.begins_with("const CARRYOVER_FIGHT: Dictionary = {"):
			out.append_array(_carryover_block(fight).split("\n"))
			while not lines[i].begins_with("}"):
				i += 1
			i += 1
			continue
		var h: RegExMatch = head.search(line)
		if h != null:
			side = h.get_string(1)
			who = h.get_string(2)
			move = h.get_string(3)
		var r: RegExMatch = res.search(line)
		if r != null and side != "":
			var key: String = r.get_string(2)
			var state: String = r.get_string(3)
			var got: Dictionary = dmg._run_enemy_side_case(who, move, key, state) if side == "enemy" \
					else dmg._run_squad_side_case(who, move, key, state)
			var new_line: String = '%s"%s:%s": [%d, %d],' % [r.get_string(1), key, state, got["hp_delta"], got["target_hp"]]
			if new_line != line:
				changed += 1
			line = new_line
		out.append(line)
		i += 1
	var f := FileAccess.open(ProjectSettings.globalize_path(FIXTURE), FileAccess.WRITE)
	f.store_string("\n".join(out))
	f.close()
	print("repin: %d damage lines changed; BUREAUCRATIA_FIGHT and CARRYOVER_FIGHT regenerated" % changed)
	_print_specials()
	dmg.free()
	fight.free()
	quit(0)


func _bureaucratia_block(fight: Node) -> String:
	var enemies: Array[Combatant] = [BattleContentSeam.enemy("enemy_clerk"),
			BattleContentSeam.enemy("enemy_clerk"), BattleContentSeam.enemy("enemy_supervisor")]
	var result: Dictionary = fight._run_fight(enemies, BattleContentSeam.rule("rule_bureaucratia_permit"),
			CharacterizationExpected.SEED_FIGHT_B, ScriptedFightCommands.BUREAUCRATIA, -1)
	var battle: BattleCore = result["battle"]
	var roster: Array[Combatant] = result["roster"]
	var s: PackedStringArray = ["const BUREAUCRATIA_FIGHT: Dictionary = {"]
	s.append('\t"commands_consumed": %d, "won": %s, "final_round": %d,' % [result["commands_consumed"],
			"true" if result["won"] else "false", battle.round_number])
	s.append('\t"rng_state": %d,' % battle.rng.state)
	s.append('\t"signal_log_codes": "%s",' % result["signal_codes"])
	s.append('\t"resolved_log": [')
	var cat_names: Dictionary = {Move.Category.ATTACK: "Move.Category.ATTACK",
			Move.Category.DEFEND: "Move.Category.DEFEND", Move.Category.SPECIAL: "Move.Category.SPECIAL"}
	for e: Dictionary in BattleContentSeam.resolved_log(battle):
		var target: String = str(roster.find(e["target"])) if e["target"] != null else "null"
		s.append('\t\t{"actor": %d, "move_name": "%s", "category": %s, "target": %s, "hp_delta": %d, "mp_delta": %d, "target_knocked_out": %s, "round_number": %d},' % [
				roster.find(e["actor"]), e["move_name"], cat_names[e["category"]], target, e["hp_delta"],
				e["mp_delta"], "true" if e["target_knocked_out"] else "false", e["round_number"]])
	s.append("\t],")
	s.append('\t"hp_snapshots": [')
	for row: Array in result["hp_snapshots"]:
		var cells: PackedStringArray = []
		for c: Array in row:
			cells.append("[%d, %d]" % [c[0], c[1]])
		s.append("\t\t[%s]," % ", ".join(cells))
	s.append("\t],")
	s.append("}")
	return "\n".join(s)


## The carryover test's own procedure (battle_scripted_fight_characterization_test.gd),
## run to its end; only the outcome fields are regenerated.
func _carryover_block(fight: Node) -> String:
	var pin: Dictionary = CharacterizationExpected.CARRYOVER_FIGHT
	var squad: Array[Combatant] = fight._fixture_squad()
	var enemies: Array[Combatant] = [BattleContentSeam.enemy("enemy_clerk"),
			BattleContentSeam.enemy("enemy_clerk"), BattleContentSeam.enemy("enemy_supervisor")]
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.SEED_FIGHT_B
	var battle := BattleCore.new(squad, enemies, rng, BattleContentSeam.rule("rule_bureaucratia_permit"))
	var won_box: Array = [false]
	battle.battle_ended.connect(func(w: bool) -> void: won_box[0] = w)
	battle.start_battle()
	BattleContentSeam.arrange_vitals(squad[0], 0, 0)
	BattleContentSeam.arrange_vitals(squad[1], pin["chef_hp"], pin["chef_mp"])
	BattleContentSeam.arrange_vitals(enemies[0], 1, 0)
	battle.start_battle(false)
	var cursor := 0
	while cursor < CharacterizationExpected.ROUND_CAP * 4:
		if battle.state == BattleCore.State.WON or battle.state == BattleCore.State.LOST:
			break
		if battle.round_number > CharacterizationExpected.ROUND_CAP:
			break
		battle.submit_action(Move.make_attack(), battle.get_living_enemies()[0])
		cursor += 1
	return "\n".join([
		"const CARRYOVER_FIGHT: Dictionary = {",
		'\t"chef_hp": %d, "chef_mp": %d,' % [pin["chef_hp"], pin["chef_mp"]],
		'\t"commands_consumed": %d, "won": %s, "final_round": %d,' % [cursor, "true" if won_box[0] else "false", battle.round_number],
		'\t"rng_state": %d, "outcome_log_size": %d,' % [rng.state, battle.outcome_log.size()],
		"}",
	])


## The squad-specials test's Clerk-dependent constants, recomputed by its
## own procedure, for a hand update.
func _print_specials() -> void:
	var b: Dictionary = CharacterizationExpected.SQUAD_FLORIDA_MAN
	var florida := Combatant.new(b["name"], b["max_hp"], b["max_mp"], b["attack"], b["defense"], b["speed"], false)
	var attacker := Combatant.new("Attacker", 30, 10, 10, 8, 10, false)
	var clerk: Combatant = BattleContentSeam.enemy("enemy_clerk")
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.SEED_A
	var battle := BattleCore.new([florida, attacker], [clerk], rng, BattleContentSeam.scripted_rule([]))
	battle.start_battle()
	battle.submit_action(BattleContentSeam.move("move_viral_stunt"), clerk)
	var o: BattleOutcome = battle.submit_action(Move.make_attack(), clerk)
	print("repin: _VIRAL_BOOSTED_ATTACK_DAMAGE = %d, _VIRAL_BOOSTED_ATTACK_RNG_STATE = %d" % [-o.hp_delta, rng.state])
	var bb: Dictionary = CharacterizationExpected.SQUAD_BAGUETTE_THROWER
	var baguette := Combatant.new(bb["name"], bb["max_hp"], bb["max_mp"], bb["attack"], bb["defense"], bb["speed"], false)
	var foes: Array[Combatant] = []
	for id: String in CharacterizationExpected.ENEMY_IDS:
		foes.append(BattleContentSeam.enemy(id))
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = CharacterizationExpected.SEED_B
	var b2 := BattleCore.new([baguette], foes, rng2, BattleContentSeam.scripted_rule([]))
	b2.start_battle()
	var dmg: PackedStringArray = []
	for f: Combatant in foes:
		BattleContentSeam.arrange_vitals(baguette, baguette.hp, baguette.max_mp)
		dmg.append(str(-b2.submit_action(BattleContentSeam.move("move_home_run"), f).hp_delta))
	print("repin: _HOME_RUN_DAMAGE = [%s], _HOME_RUN_RNG_STATE = %d" % [", ".join(dmg), rng2.state])
