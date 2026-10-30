## One outcome's beat: the actor's action, each reactor's reaction, the HP
## numbers and the punch (ADR-0006 §7 "Outcome-to-animation map", Key
## Interfaces; GDD sprite-camera-presentation AC-14b). Built once by
## `BeatPlan.build()` at `action_resolved` and not changed afterwards.
##
## Usage example:
## [codeblock]
## controller.beat_impact.connect(func(plan: BeatPlan) -> void:
##     if plan.punch:
##         hit_punch.on_impact(plan.punch_hp_delta(), plan.knockout,
##                 plan.actor == controller.get_boss_combatant(), Vector2.RIGHT))
## [/codeblock]
class_name BeatPlan
extends RefCounted

## The actor's action role, chosen from the outcome's category.
enum ActionRole { ATTACK, SPECIAL, DEFEND }
## A reacting combatant's reaction.
enum Reaction { HIT, KNOCKOUT, HEAL, STATUS }

## The original outcome, for logging.
var outcome: BattleOutcome
## Who acts.
var actor: Combatant
## The action role.
var action_role: ActionRole = ActionRole.ATTACK
## The move's display name (the stopgap key for a move-specific animation).
var move_name: String = ""
## Combatant -> Reaction; never contains the actor.
var reactions: Dictionary = {}
## Combatant -> HP change; non-zero only, the actor included.
var hp_changes: Dictionary = {}
## True if any reactor is HIT or KNOCKOUT with a negative HP change.
var punch: bool = false
## True if `punch` and (a knockout, or the actor is the boss).
var big_punch: bool = false
## True if any reactor is KNOCKOUT.
var knockout: bool = false
## Always false in MVP (GDD Open Question 5b).
var protected: bool = false
## Unscaled post-impact hold in seconds: 0 with no reactors, the knockout
## hold on a knockout, else `reaction_hold`.
var hold: float = 0.0
## 1x wind-up seconds, or -1.0 on the debug path (no action animation).
var windup_1x: float = -1.0


## Builds the plan for `p_outcome` from the snapshots before and after it
## (Combatant -> CombatantDisplay). `windup` is `(BeatPlan) -> float` and
## `ko_landing` is `(Combatant) -> float` (ADR-0006 §1); `boss` may be null.
## Example: [code]var plan := BeatPlan.build(outcome, before, after, null, windup, ko_landing, config)[/code]
static func build(p_outcome: BattleOutcome, before: Dictionary, after: Dictionary,
		boss: Combatant, windup: Callable, ko_landing: Callable,
		config: PresentationConfig) -> BeatPlan:
	var plan := BeatPlan.new()
	plan.outcome = p_outcome
	plan.actor = p_outcome.actor
	plan.move_name = p_outcome.move_name
	match p_outcome.category:
		Move.Category.DEFEND:
			plan.action_role = ActionRole.DEFEND
		Move.Category.SPECIAL:
			plan.action_role = ActionRole.SPECIAL
		_:
			plan.action_role = ActionRole.ATTACK
	for c: Combatant in after.keys():
		var after_d: CombatantDisplay = after[c]
		var before_d: CombatantDisplay = before.get(c, after_d)
		var delta: int = after_d.hp - before_d.hp
		if delta != 0:
			plan.hp_changes[c] = delta
		if c == plan.actor:
			continue
		var is_target: bool = c == p_outcome.target
		if delta < 0 and after_d.hp == 0:
			plan.reactions[c] = Reaction.KNOCKOUT
		elif delta < 0:
			plan.reactions[c] = Reaction.HIT
		elif delta > 0:
			plan.reactions[c] = Reaction.HEAL
		elif is_target and p_outcome.category == Move.Category.ATTACK:
			plan.reactions[c] = Reaction.HIT
		elif is_target:
			plan.reactions[c] = Reaction.STATUS
	var ko_max: float = 0.0
	for c: Combatant in plan.reactions.keys():
		var r: int = plan.reactions[c]
		var delta_c: int = plan.hp_changes.get(c, 0)
		if (r == Reaction.HIT or r == Reaction.KNOCKOUT) and delta_c < 0:
			plan.punch = true
		if r == Reaction.KNOCKOUT:
			plan.knockout = true
			if ko_landing.is_valid():
				ko_max = maxf(ko_max, float(ko_landing.call(c)))
	plan.big_punch = plan.punch and (plan.knockout or (boss != null and plan.actor == boss))
	if plan.reactions.is_empty():
		plan.hold = 0.0
	elif plan.knockout:
		plan.hold = maxf(config.ko_hold, ko_max)
	else:
		plan.hold = config.reaction_hold
	plan.windup_1x = float(windup.call(plan)) if windup.is_valid() else -1.0
	return plan


## True when the actor has no action animation (debug builds only).
func is_debug_path() -> bool:
	return windup_1x < 0.0


## The most negative HP change among HIT/KNOCKOUT reactors (0 if none): the
## `hp_delta` the Battle mode passes to `HitPunch.on_impact()` on `beat_impact`.
func punch_hp_delta() -> int:
	var worst: int = 0
	for c: Combatant in reactions.keys():
		var r: int = reactions[c]
		if r == Reaction.HIT or r == Reaction.KNOCKOUT:
			worst = mini(worst, int(hp_changes.get(c, 0)))
	return worst


## Starts this beat's punch on `hit_punch` (at most one per beat, AC-10);
## call on `beat_impact`. Returns whether a punch started.
func start_punch(hit_punch: HitPunch, boss: Combatant, dir: Vector2) -> bool:
	if not punch:
		return false
	return hit_punch.on_impact(punch_hp_delta(), knockout, boss != null and actor == boss, dir)


## The move-specific animation key for `move_name` ("Family Meal" ->
## `&"family_meal"`). Stopgap until moves carry IDs (ADR-0006 §7).
func move_animation_key() -> StringName:
	return StringName(move_name.to_snake_case())


## The actor's animation: the move-specific one when `has_animation`
## (`(StringName) -> bool`) reports it, else the role's fallback. Defend
## always plays `defend`.
func action_animation(has_animation: Callable) -> StringName:
	if action_role == ActionRole.DEFEND:
		return &"defend"
	var key: StringName = move_animation_key()
	if bool(has_animation.call(key)):
		return key
	return &"attack"


## A reactor's animation on impact: HIT -> hit, KNOCKOUT -> knockout, HEAL
## -> heal or `&""` (stay in the current pose), STATUS -> status or hit.
static func reaction_animation(reaction: int, has_animation: Callable) -> StringName:
	match reaction:
		Reaction.KNOCKOUT:
			return &"knockout"
		Reaction.HEAL:
			return &"heal" if bool(has_animation.call(&"heal")) else &""
		Reaction.STATUS:
			return &"status" if bool(has_animation.call(&"status")) else &"hit"
	return &"hit"


## The floating number for an HP change: "+N" for a heal, "-N" for damage,
## "" for 0 (no number ever reads "0").
static func number_text(delta: int) -> String:
	if delta == 0:
		return ""
	return ("+%d" % delta) if delta > 0 else str(delta)
