## Test harness for `BattleReplayController` (ADR-0006): a stub `BattleCore`
## signal source (a real `BattleCore` that is never started, whose signals
## the test emits itself), fixed-step frame driving, and an event recorder.
##
## Usage example:
## [codeblock]
## var kit := ReplayTestKit.new(PresentationConfig.new(), 0.3)
## kit.emit_hit(kit.squad[0], kit.enemies[0], 5)
## kit.run_until_idle()
## [/codeblock]
class_name ReplayTestKit
extends RefCounted

## Frame step used by `step()`: 60 Hz.
const FRAME_STEP: float = 1.0 / 60.0

var battle: BattleCore
var controller: BattleReplayController
var config: PresentationConfig
var squad: Array[Combatant] = []
var enemies: Array[Combatant] = []
## Every recorded event: {"event": String, "plan": BeatPlan or null, "frame": int}.
var events: Array[Dictionary] = []
## 1x wind-up per actor; actors absent use `default_windup`.
var windup_by_actor: Dictionary = {}
var default_windup: float = 0.3
## ko_landing per combatant; absent -> 0.0.
var ko_landing_by_combatant: Dictionary = {}
var frame: int = 0
var h: float = FRAME_STEP


## Builds two squad members, two enemies and a controller with `p_config`;
## every outcome's wind-up defaults to `p_default_windup` seconds.
func _init(p_config: PresentationConfig, p_default_windup: float = 0.3) -> void:
	config = p_config
	default_windup = p_default_windup
	squad = [Combatant.new("S1", 40, 10, 10, 5, 10, false), Combatant.new("S2", 40, 10, 10, 5, 9, false)]
	enemies = [Combatant.new("E1", 40, 10, 10, 5, 8, true), Combatant.new("E2", 40, 10, 10, 5, 7, true)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	battle = BattleCore.new(squad, enemies, rng, BattleContentSeam.scripted_rule([]))
	controller = BattleReplayController.new(battle, _windup, _ko_landing, config)
	for sig: String in ["replay_started", "replay_finished", "replay_cancelled", "display_resynced"]:
		controller.connect(sig, _record.bind(sig, null))
	# Bound methods, not lambdas: a lambda using this kit's members holds the
	# kit strongly, and the controller holds the lambda -- a RefCounted cycle
	# that leaked every kit, controller and BattleCore.
	controller.beat_started.connect(_record_plan.bind("beat_started"))
	controller.beat_impact.connect(_record_plan.bind("beat_impact"))
	controller.beat_finished.connect(_record_plan.bind("beat_finished"))
	controller.hold_started.connect(_record.bind("hold_started", null).unbind(2))
	controller.hold_finished.connect(_record.bind("hold_finished", null).unbind(1))
	controller.turn_started_after_replay.connect(_record.bind("turn", null).unbind(1))
	controller.battle_ended_after_replay.connect(_record.bind("end", null).unbind(1))
	controller.latch_changed.connect(_record_latch)


func _windup(plan: BeatPlan) -> float:
	return float(windup_by_actor.get(plan.actor, default_windup))


func _ko_landing(c: Combatant) -> float:
	return float(ko_landing_by_combatant.get(c, 0.0))


func _record(event_name: String, plan: BeatPlan) -> void:
	events.append({"event": event_name, "plan": plan, "frame": frame})


func _record_plan(plan: BeatPlan, event_name: String) -> void:
	_record(event_name, plan)


func _record_latch(on: bool) -> void:
	_record("latch_on" if on else "latch_off", null)


## Applies `dmg` to `target` and emits an ATTACK outcome for it.
func emit_hit(actor: Combatant, target: Combatant, dmg: int) -> void:
	var removed: int = target.take_damage(dmg)
	battle.action_resolved.emit(BattleOutcome.new(actor, "Attack", Move.Category.ATTACK, target,
			-removed, 0, target.is_knocked_out(), battle.round_number))


## Emits a DEFEND outcome for `actor`.
func emit_defend(actor: Combatant) -> void:
	actor.is_defending = true
	battle.action_resolved.emit(BattleOutcome.new(actor, "Defend", Move.Category.DEFEND, null,
			0, 0, false, battle.round_number))


## Emits `turn_started(c)`.
func emit_turn(c: Combatant) -> void:
	battle.turn_started.emit(c)


## Advances `n` frames of `h` seconds.
func step(n: int = 1) -> void:
	for i: int in n:
		frame += 1
		controller.advance(h)


## Steps until the controller is IDLE (or `max_frames` pass).
func run_until_idle(max_frames: int = 2000) -> void:
	var guard: int = 0
	while controller.get_state() != BattleReplayController.State.IDLE and guard < max_frames:
		step()
		guard += 1


## Frames at which `event_name` fired for `plan` (any plan when null).
func frames_of(event_name: String, plan: BeatPlan = null) -> Array[int]:
	var out: Array[int] = []
	for e: Dictionary in events:
		if e["event"] == event_name and (plan == null or e["plan"] == plan):
			out.append(int(e["frame"]))
	return out


## Every distinct plan in start order.
func plans() -> Array[BeatPlan]:
	var out: Array[BeatPlan] = []
	for e: Dictionary in events:
		if e["event"] == "beat_started":
			out.append(e["plan"])
	return out


## Seconds from `plan`'s start to its impact and to its end.
func beat_times(plan: BeatPlan) -> Dictionary:
	var s: int = frames_of("beat_started", plan)[0]
	return {
		"impact": float(frames_of("beat_impact", plan)[0] - s) * h,
		"end": float(frames_of("beat_finished", plan)[0] - s) * h,
	}
