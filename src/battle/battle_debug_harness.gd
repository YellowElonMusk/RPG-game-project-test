## Minimal manual-test harness for BattleCore. Not a real HUD (Story 005
## owns that) — plain Buttons and Labels only, so the battle-core state
## machine can be driven and watched by hand. Run this scene directly from
## the editor ("Run Current Scene"); it is not wired into project.godot's
## main scene.
extends Control

const TEST_SPECIAL_MP_COST: int = 4

var _battle: BattleCore
var _log_label: Label
var _status_label: Label
var _command_box: VBoxContainer


func _ready() -> void:
	_build_data_and_battle()
	_build_ui()
	_battle.turn_started.connect(func(_combatant: Combatant) -> void: _render_turn())
	_battle.action_resolved.connect(_on_action_resolved)
	_battle.round_advanced.connect(_on_round_advanced)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.start_battle()
	_render_turn()


func _build_data_and_battle() -> void:
	# Placeholder stats only (within the Stats & Damage GDD F1 ranges) — not
	# the branded recruits/enemies from the game brief. Content authoring
	# for those is a later story's job.
	var squad: Array[Combatant] = [
		Combatant.new("Hero A", 30, 10, 12, 8, 10, false),
		Combatant.new("Hero B", 30, 12, 11, 8, 10, false),
	]
	# Story 002: the Bureaucratia roster and rule, so the permit ban and
	# hunker-down behavior can be exercised by hand.
	var enemies: Array[Combatant] = [
		BureaucratiaRule.make_clerk(),
		BureaucratiaRule.make_clerk(),
		BureaucratiaRule.make_supervisor(),
	]
	_battle = BattleCore.new(squad, enemies, null, BureaucratiaRule.new())


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	add_child(root)

	_status_label = Label.new()
	root.add_child(_status_label)

	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(500, 300)
	root.add_child(_log_label)

	_command_box = VBoxContainer.new()
	root.add_child(_command_box)

	var retry_button := Button.new()
	retry_button.text = "Retry"
	retry_button.pressed.connect(_on_retry_pressed)
	root.add_child(retry_button)


func _render_turn() -> void:
	for child in _command_box.get_children():
		child.queue_free()

	if _battle.state != BattleCore.State.SQUAD_TURN:
		return

	var actor := _battle.get_active_combatant()
	var specials_allowed: bool = _battle.faction_rule.specials_allowed(_battle.round_number)
	_status_label.text = "Round %d — %s's turn (HP %d/%d, MP %d/%d) — specials %s" % [
		_battle.round_number, actor.display_name, actor.hp, actor.max_hp,
		actor.mp, actor.max_mp, "ALLOWED" if specials_allowed else "BANNED"]

	var attack_button := Button.new()
	attack_button.text = "Attack"
	attack_button.pressed.connect(_on_attack_pressed)
	_command_box.add_child(attack_button)

	var defend_button := Button.new()
	defend_button.text = "Defend"
	defend_button.pressed.connect(func() -> void: _submit(Move.make_defend(), null))
	_command_box.add_child(defend_button)

	var special_button := Button.new()
	special_button.text = "Test Special (%d MP)" % TEST_SPECIAL_MP_COST
	special_button.disabled = not specials_allowed or not actor.can_afford(TEST_SPECIAL_MP_COST)
	special_button.pressed.connect(_on_special_pressed)
	_command_box.add_child(special_button)


func _on_attack_pressed() -> void:
	var living_enemies := _battle.get_living_enemies()
	if living_enemies.is_empty():
		return
	_submit(Move.make_attack(), living_enemies[0])


func _on_special_pressed() -> void:
	var living_enemies := _battle.get_living_enemies()
	if living_enemies.is_empty():
		return
	var test_special := Move.new("Test Special", Move.Category.SPECIAL,
			TEST_SPECIAL_MP_COST, 0, Move.TargetType.SINGLE_ENEMY)
	_submit(test_special, living_enemies[0])


func _submit(move: Move, target: Combatant) -> void:
	_battle.submit_action(move, target)
	_render_turn()


func _on_retry_pressed() -> void:
	_log_label.text = ""
	_battle.retry_battle()
	_render_turn()


func _on_action_resolved(outcome: BattleOutcome) -> void:
	var line: String = "%s used %s" % [outcome.actor.display_name, outcome.move_name]
	if outcome.target != null:
		line += " on %s" % outcome.target.display_name
	if outcome.hp_delta != 0:
		line += " (%d HP)" % outcome.hp_delta
	if outcome.mp_delta != 0:
		line += " (%d MP)" % outcome.mp_delta
	if outcome.target_knocked_out:
		line += " — knocked out!"
	_log_label.text += line + "\n"


func _on_round_advanced(round_number: int) -> void:
	_log_label.text += "— Round %d —\n" % round_number


func _on_battle_ended(won: bool) -> void:
	_status_label.text = "BATTLE OVER — %s (press Retry)" % ("WIN" if won else "LOSS")
	for child in _command_box.get_children():
		child.queue_free()
