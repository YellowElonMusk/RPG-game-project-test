## Regression (story 060 Finding 4): on Retry, `restore_start_snapshot()`
## clears every beat number, and `BattleHud._on_number_cleared` used to cast a
## float label that its fade tween had already freed (`as Label` on a freed
## object: "Trying to cast a freed object"), aborting before the stale entry
## was erased. A freed label must read as "no number" and be dropped cleanly.
extends GdUnitTestSuite

var _hud: BattleHud
var _battle: BattleCore


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	_hud = null
	_battle = null


func _make_hud() -> Combatant:
	var hero := Combatant.new("Hero", 30, 10, 8, 4, 6, false)
	var foe: Combatant = BattleContentSeam.enemy("enemy_security_drone")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_battle = BattleCore.new([hero], [foe], rng, BattleContentSeam.rule("rule_megacorp_billing"))
	_hud = auto_free((load("res://src/battle/ui/battle_hud.tscn") as PackedScene).instantiate()) as BattleHud
	add_child(_hud)
	_hud.setup(_battle)
	return foe


func test_number_cleared_after_its_label_was_freed_drops_the_entry() -> void:
	var foe: Combatant = _make_hud()
	_hud._on_number_shown(foe, "5")
	var label: Label = _hud._number_labels.get(foe) as Label
	assert_object(label).is_not_null()
	label.free()  # the fade tween's queue_free has already run

	_hud._on_number_cleared(foe)

	assert_bool(_hud._number_labels.has(foe)).override_failure_message(
			"a freed float label stayed registered after number_cleared").is_false()
	assert_str(_hud.number_over(foe)).is_equal("")


func test_number_over_a_freed_label_reads_empty() -> void:
	var foe: Combatant = _make_hud()
	_hud._on_number_shown(foe, "5")
	(_hud._number_labels.get(foe) as Label).free()

	assert_str(_hud.number_over(foe)).is_equal("")
