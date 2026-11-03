extends SceneTree
## Balance probe (the open "too easy" item; game brief MVP difficulty): plays
## every shipped encounter `--runs` times per policy on `BattleCore`, from a
## fresh full-HP shipped squad, and prints the win rate, mean rounds, mean
## squad HP lost and mean knockouts. It emits observations, never verdicts:
## what counts as "too easy" is a design call.
##
##   naive  every squad turn: Attack the living enemy with the least HP
##   smart  heal (a SINGLE_ALLY special) the most-hurt ally below 50% HP when
##          allowed and affordable; else the first allowed, affordable
##          SINGLE_ENEMY special on the weakest enemy; else Attack it
##
## Headless:
##
##   godot --headless --path . -s res://tools/balance/fight_sim.gd [-- --runs=300 --encounter=enc_paris_supervisor]
##   ... -- --roster=enemy_supervisor,enemy_clerk,enemy_clerk --boss=1   (an ad-hoc fight)

const DEFAULT_RUNS: int = 300
const TURN_CAP: int = 2000

var _catalog: ContentCatalogService = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var runs: int = DEFAULT_RUNS
	var only: String = ""
	var roster: String = ""
	var boss: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.substr(7))
		elif a.begins_with("--roster="):
			roster = a.substr(9)
		elif a.begins_with("--boss="):
			boss = a.substr(7) == "1"
		elif a.begins_with("--encounter="):
			only = a.substr(12)
	_catalog = BattleCatalog.shipped()
	ContentBootstrap.run(_catalog)
	if _catalog.state != ContentCatalogService.State.READY:
		printerr("fight_sim: content boot failed: %s" % [_catalog.report])
		quit(1)
		return
	print("fight_sim: %d runs per policy" % runs)
	print("%-28s %-6s %6s %7s %9s %5s" % ["encounter", "policy", "win%", "rounds", "hp_lost%", "KOs"])
	var records: Array = _catalog.all_records(&"encounter")
	if not roster.is_empty():
		var adhoc := EncounterData.new()
		adhoc.id = "adhoc"
		adhoc.enemy_ids = PackedStringArray(roster.split(","))
		adhoc.faction_id = "faction_bureaucratia"
		adhoc.battle_stage_id = "stage_chapter_interim"
		adhoc.is_boss = boss
		records = [adhoc]
	for rec: Resource in records:
		var enc := rec as EncounterData
		if not only.is_empty() and enc.id != only:
			continue
		for policy: String in ["naive", "smart"]:
			var s: Dictionary = _simulate(enc, policy, runs)
			print("%-28s %-6s %6.1f %7.1f %9.1f %5.2f   %s" % [enc.id, policy, s["win"], s["rounds"],
					s["hp_lost"], s["kos"], ",".join(enc.enemy_ids)])
	quit(0)


func _simulate(enc: EncounterData, policy: String, runs: int) -> Dictionary:
	var wins: int = 0
	var rounds: float = 0.0
	var hp_lost: float = 0.0
	var kos: float = 0.0
	for seed: int in runs:
		var payload := BattleEntryPayload.new()
		payload.descriptor = OverworldMode.build_descriptor(enc)
		payload.party = ChapterFlow.build_squad(_catalog)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + seed
		var core: BattleCore = BattleFactory.build(payload, rng).core
		if core == null:
			continue
		core.start_battle(false)
		var max_hp: int = 0
		for c: Combatant in core.squad:
			max_hp += c.max_hp
		var guard: int = 0
		while (core.state == BattleCore.State.SQUAD_TURN or core.state == BattleCore.State.ENEMY_TURN) and guard < TURN_CAP:
			if core.state == BattleCore.State.SQUAD_TURN:
				var choice: Array = _choose(core, policy)
				core.submit_action(choice[0], choice[1])
			guard += 1
		if core.state == BattleCore.State.WON:
			wins += 1
		rounds += core.round_number
		var hp_now: int = 0
		var down: int = 0
		for c: Combatant in core.squad:
			hp_now += maxi(c.hp, 0)
			down += 1 if c.hp <= 0 else 0
		hp_lost += 100.0 * float(max_hp - hp_now) / float(max_hp)
		kos += down
	return {"win": 100.0 * wins / runs, "rounds": rounds / runs, "hp_lost": hp_lost / runs, "kos": kos / runs}


func _choose(core: BattleCore, policy: String) -> Array:
	var actor: Combatant = core.get_active_combatant()
	var weakest: Combatant = _least_hp(core.get_living_enemies())
	if policy == "smart":
		var hurt: Combatant = _most_hurt(core.get_living_squad())
		var moves: Array[Move] = SquadMoves.moves_for(actor)
		if hurt != null and float(hurt.hp) / float(hurt.max_hp) < 0.5:
			for m: Move in moves:
				if m.target_type == Move.TargetType.SINGLE_ALLY and _usable(core, actor, m):
					return [m, hurt]
		for m: Move in moves:
			if m.category == Move.Category.SPECIAL and m.target_type == Move.TargetType.SINGLE_ENEMY and _usable(core, actor, m):
				return [m, weakest]
	return [Move.make_attack(), weakest]


func _usable(core: BattleCore, actor: Combatant, m: Move) -> bool:
	var rule: FactionRule = core.faction_rule
	if m.category == Move.Category.SPECIAL and not rule.specials_allowed(core.round_number):
		return false
	return rule.move_allowed(actor, m) and actor.can_afford(m.mp_cost)


func _least_hp(list: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	for c: Combatant in list:
		if best == null or c.hp < best.hp:
			best = c
	return best


func _most_hurt(list: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	for c: Combatant in list:
		if best == null or float(c.hp) / c.max_hp < float(best.hp) / best.max_hp:
			best = c
	return best
