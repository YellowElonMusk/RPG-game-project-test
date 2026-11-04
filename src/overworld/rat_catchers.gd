## Decides when the Rat Catchers turn up (narrative bible §6.5). Pure: reads
## the `WorldState`, the config and an injected RNG; the only write is
## `mark_met()`, which stores the meeting as story flags so it is saved.
##
## - Before the region is liberated: an ambush on the chapter's street
##   segment, with `ambush_chance(alien_points)`, at most
##   `ambushes_per_map_max` times per map. Never at 0 alien points.
## - On the walk home (the region liberated): the Captain, once per chapter,
##   when alien points reach `captain_min_alien_points`.
##
## Usage example:
## [codeblock]
## var enc_id: String = RatCatchers.pick(world_state, map_id, liberated, rng, cfg)
## if not enc_id.is_empty():
##     RatCatchers.mark_met(world_state, map_id, enc_id, cfg)
## [/codeblock]
class_name RatCatchers
extends RefCounted


## The chance of an ambush on one map entry: 0 at 0 alien points, else
## `base + per_point * alien_points` capped at `max_chance`.
static func ambush_chance(alien_points: int, cfg: RatCatcherConfig) -> float:
	if alien_points <= 0:
		return 0.0
	return minf(cfg.ambush_max_chance, cfg.ambush_base_chance + cfg.ambush_per_point * alien_points)


## The encounter id the Rat Catchers start on entering `map_id`, or "".
## Rolls `rng` once, and only for an ambush that is still possible.
static func pick(world_state: WorldState, map_id: String, liberated: bool,
		rng: RandomNumberGenerator, cfg: RatCatcherConfig) -> String:
	if world_state == null or cfg == null or not cfg.tier_by_map.has(map_id):
		return ""
	var tier: String = cfg.tier_by_map[map_id]
	if liberated:
		if world_state.alien_points >= cfg.captain_min_alien_points \
				and not world_state.has_flag(captain_flag(tier)):
			return captain_encounter(tier)
		return ""
	if ambushes_met(world_state, map_id, cfg) >= cfg.ambushes_per_map_max:
		return ""
	var chance: float = ambush_chance(world_state.alien_points, cfg)
	if chance <= 0.0 or rng == null:
		return ""
	return ambush_encounter(tier) if rng.randf() < chance else ""


## Records the meeting: the Captain's once-per-chapter flag, or the next
## ambush count flag for `map_id`.
static func mark_met(world_state: WorldState, map_id: String, enc_id: String,
		cfg: RatCatcherConfig) -> void:
	if world_state == null:
		return
	if is_captain(enc_id):
		world_state.set_flag(captain_flag(enc_id.trim_prefix("enc_rat_captain_")))
		return
	world_state.set_flag(ambush_flag(map_id, ambushes_met(world_state, map_id, cfg) + 1))


## How many ambushes `map_id` has had.
static func ambushes_met(world_state: WorldState, map_id: String, cfg: RatCatcherConfig) -> int:
	var n: int = 0
	while n < cfg.ambushes_per_map_max and world_state.has_flag(ambush_flag(map_id, n + 1)):
		n += 1
	return n


static func ambush_encounter(tier: String) -> String:
	return "enc_rat_ambush_" + tier


static func captain_encounter(tier: String) -> String:
	return "enc_rat_captain_" + tier


static func is_captain(enc_id: String) -> bool:
	return enc_id.begins_with("enc_rat_captain_")


static func is_rat_catcher_encounter(enc_id: String) -> bool:
	return enc_id.begins_with("enc_rat_")


static func captain_flag(tier: String) -> String:
	return "rat_captain_met_" + tier


static func ambush_flag(map_id: String, n: int) -> String:
	return "rat_ambush_%s_%d" % [map_id, n]
