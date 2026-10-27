## Story 021, AC-15 (TR-content-006; ADR-0001 Rule 4): a Move's
## EffectDescriptors round-trip through the catalog untouched, and loading
## triggers no game effect. "No game effect" is made measurable three ways:
## the loaded effects deep-equal the fixture (T1); every record script
## declares no method beyond a `get_` getter or `_init` (T2); and loading
## emits no signal the catalog does not itself define (T3). Registers the
## five migrated EffectDescriptor types as a test double for Turn Battle
## System, which owns the real call. Builds a fresh ContentCatalogService
## (never the autoload).
extends GdUnitTestSuite

const ROOT := "res://tests/unit/content_data/fixtures/effect_passthrough"
const TURN_BATTLE_TYPES: Array[String] = ["stun", "heal_party", "heal_single", "damage_debuff", "direct_damage"]

## Every record type directory under src/data/records/ (story's T2 scope).
const RECORD_SCRIPTS: Array[String] = [
	"res://src/data/records/character_data.gd",
	"res://src/data/records/enemy_data.gd",
	"res://src/data/records/move_data.gd",
	"res://src/data/records/faction_data.gd",
	"res://src/data/records/faction_rule_data.gd",
	"res://src/data/records/quirk_state_data.gd",
	"res://src/data/records/combo_data.gd",
	"res://src/data/records/item_data.gd",
	"res://src/data/records/input_bindings.gd",
	"res://src/data/records/map_data.gd",
	"res://src/data/records/encounter_data.gd",
	"res://src/data/records/occupation_stage_data.gd",
]

var _catalog: ContentCatalogService


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())
	_catalog.register_known_effect_types(&"turn_battle", PackedStringArray(TURN_BATTLE_TYPES))


## T1: a Move's effects, including a nested Dictionary (scaling), an Array
## parameter (tags) and an unregistered parameter key (flavour), load
## deep-equal to the fixture.
func test_effects_round_trip_deep_equal_to_fixture() -> void:
	var result: Error = _catalog.load_all(ROOT)

	assert_int(result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	var rec: MoveData = _catalog.get_record(&"move", "move_passthrough")
	assert_object(rec).is_not_null()
	assert_array(rec.effects).is_equal([
		{"type": "direct_damage", "amount": 12, "scaling": {"multiplier": 1.5, "stat": "attack"}},
		{"type": "stun", "rounds": 2, "tags": ["debuff", "control"]},
		{"type": "heal_single", "amount": 8, "flavour": "unregistered param key"},
	])


## T2: every record script declares no method beyond a get_ getter or _init —
## the catalog copies data, it never runs it.
func test_record_scripts_declare_no_methods_beyond_getters() -> void:
	for path: String in RECORD_SCRIPTS:
		var script: Script = load(path)
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			assert_bool(name.begins_with("get_") or name == "_init") \
					.override_failure_message("%s declares %s, not a getter or _init" % [path, name]) \
					.is_true()


## T3: loading a Move with known EffectDescriptor types emits no signal.
## ContentCatalogService declares no signal of its own (verified: `grep
## "^signal" src/data/content_catalog.gd` finds none), so every signal in its
## (inherited, Node-level) signal list must stay unemitted.
func test_loading_emits_no_signal() -> void:
	var monitor := monitor_signals(_catalog)

	_catalog.load_all(ROOT)

	# load_all() is synchronous and already finished: a short timeout is
	# enough to confirm absence without a 2s-per-signal wait.
	for signal_def: Dictionary in _catalog.get_signal_list():
		await assert_signal(monitor).wait_until(50).is_not_emitted(signal_def["name"])
