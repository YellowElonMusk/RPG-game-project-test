## Story 013 (ADR-0001 Migration Step 2; ADR-0011 §4; ADR-0012 §3;
## TR-content-005): the two shipped factions exist as alien Faction records
## whose shape, identity colour, `rule_id` and asset IDs equal the shipped
## code -- "moved as-is, never retuned" enforced by this test against
## `MigratedRecordsExpected`, not by review alone. Each `.tres` is loaded
## directly with `CACHE_MODE_IGNORE`; the catalog-level zero-error load is
## story 021's job, not this one's.
##
## Shared across content-migration stories 013-019 -- each story adds only
## its own test cases below its own section comment.
extends GdUnitTestSuite

const _BUREAUCRATIA_PATH: String = "res://data/factions/faction_bureaucratia.tres"
const _MEGACORP_PATH: String = "res://data/factions/faction_megacorp.tres"


func _load(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)


# --- Story 013: faction_bureaucratia, faction_megacorp ---

func test_faction_bureaucratia_matches_shipped_identity() -> void:
	var faction: FactionData = _load(_BUREAUCRATIA_PATH) as FactionData
	assert_object(faction).override_failure_message("failed to load %s" % _BUREAUCRATIA_PATH).is_not_null()

	assert_str(faction.id).is_equal(MigratedRecordsExpected.BUREAUCRATIA_ID)
	assert_str(faction.kind).is_equal(MigratedRecordsExpected.ALIEN_KIND)
	assert_str(faction.base_shape).is_equal(MigratedRecordsExpected.BUREAUCRATIA_BASE_SHAPE)
	assert_str(faction.display_name).is_equal(MigratedRecordsExpected.BUREAUCRATIA_DISPLAY_NAME)
	assert_str(faction.rule_id).is_equal(MigratedRecordsExpected.BUREAUCRATIA_RULE_ID)
	assert_str(faction.backup_icon_id).is_equal(MigratedRecordsExpected.BUREAUCRATIA_BACKUP_ICON_ID)
	assert_str(faction.patrol_archetype_id).is_equal(MigratedRecordsExpected.BUREAUCRATIA_PATROL_ARCHETYPE_ID)
	assert_bool(Color(faction.signature_color).is_equal_approx(
			Color("#" + CharacterizationExpected.BUREAUCRATIA_IDENTITY_COLOR_HTML))).is_true()


func test_faction_megacorp_matches_shipped_identity() -> void:
	var faction: FactionData = _load(_MEGACORP_PATH) as FactionData
	assert_object(faction).override_failure_message("failed to load %s" % _MEGACORP_PATH).is_not_null()

	assert_str(faction.id).is_equal(MigratedRecordsExpected.MEGACORP_ID)
	assert_str(faction.kind).is_equal(MigratedRecordsExpected.ALIEN_KIND)
	assert_str(faction.base_shape).is_equal(MigratedRecordsExpected.MEGACORP_BASE_SHAPE)
	assert_str(faction.display_name).is_equal(MigratedRecordsExpected.MEGACORP_DISPLAY_NAME)
	assert_str(faction.rule_id).is_equal(MigratedRecordsExpected.MEGACORP_RULE_ID)
	assert_str(faction.backup_icon_id).is_equal(MigratedRecordsExpected.MEGACORP_BACKUP_ICON_ID)
	assert_str(faction.patrol_archetype_id).is_equal(MigratedRecordsExpected.MEGACORP_PATROL_ARCHETYPE_ID)
	assert_bool(Color(faction.signature_color).is_equal_approx(
			Color("#" + CharacterizationExpected.MEGACORP_IDENTITY_COLOR_HTML))).is_true()


# --- Story 014: the nine enemy named-attack moves ---

func test_named_attack_moves_match_shipped_values() -> void:
	for id: String in MigratedRecordsExpected.NAMED_ATTACK_IDS:
		var move: MoveData = _load("res://data/moves/%s.tres" % id) as MoveData
		assert_object(move).override_failure_message("failed to load %s" % id).is_not_null()

		var expected: Dictionary = MigratedRecordsExpected.NAMED_ATTACKS[id]
		assert_str(move.display_name).override_failure_message(
				"%s display_name" % id).is_equal(expected["display_name"])
		assert_str(move.target_type).override_failure_message(
				"%s target_type" % id).is_equal(MigratedRecordsExpected.NAMED_ATTACK_TARGET_TYPE)
		assert_int(move.cost).override_failure_message(
				"%s cost" % id).is_equal(MigratedRecordsExpected.NAMED_ATTACK_COST)
		assert_array(move.effects).override_failure_message(
				"%s effects" % id).is_equal([
				{"type": MigratedRecordsExpected.NAMED_ATTACK_EFFECT_TYPE, "power": expected["power"]}])


## Edge case: Attack and Defend stay code-side factories (Control Manifest,
## this layer) -- no `move_attack`/`move_defend` records.
func test_no_move_attack_or_move_defend_records_exist() -> void:
	assert_bool(FileAccess.file_exists("res://data/moves/move_attack.tres")).is_false()
	assert_bool(FileAccess.file_exists("res://data/moves/move_defend.tres")).is_false()


## TR-content-006: the catalog stores EffectDescriptors uninterpreted. A
## READY catalog's copy of each named attack's `effects` deep-equals the raw
## `.tres` value, and no `src/data/**/*.gd` file references the `power` key
## -- the catalog never reads what it stores.
func test_named_attack_effects_are_stored_uninterpreted() -> void:
	var catalog := auto_free(ContentCatalogService.new()) as ContentCatalogService
	var result: ContentBootResult = ContentBootstrap.run(catalog, "res://data")
	assert_object(result).is_not_null()
	assert_int(catalog.state).override_failure_message(
			"report: %s" % [catalog.report]).is_equal(ContentCatalogService.State.READY)

	for id: String in MigratedRecordsExpected.NAMED_ATTACK_IDS:
		var raw: MoveData = _load("res://data/moves/%s.tres" % id) as MoveData
		var record: MoveData = catalog.get_record(&"move", id)
		assert_array(record.effects).override_failure_message(
				"%s: catalog effects vs raw .tres" % id).is_equal(raw.effects)

	var offending: Array[String] = _scan_for_power_token(DirAccess.open("res://src/data"), "res://src/data")
	assert_int(offending.size()).override_failure_message(
			"files referencing 'power': %s" % [offending]).is_equal(0)


func _scan_for_power_token(dir: DirAccess, path: String) -> Array[String]:
	var offending: Array[String] = []
	if dir == null:
		offending.append("%s (could not open)" % path)
		return offending
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			offending.append_array(_scan_for_power_token(DirAccess.open(full), full))
		elif entry.ends_with(".gd"):
			var content: String = FileAccess.get_file_as_string(full)
			if content.contains("power"):
				offending.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return offending


# --- Story 015 (merged with 016): the five Bureaucratia/MegaCorp enemies ---

func test_enemy_records_match_shipped_roster() -> void:
	for id: String in CharacterizationExpected.ENEMY_IDS:
		var enemy: EnemyData = _load("res://data/enemies/%s.tres" % id) as EnemyData
		assert_object(enemy).override_failure_message("failed to load %s" % id).is_not_null()

		var stats: Dictionary = CharacterizationExpected.ENEMY_STATS[id]
		var record_only: Dictionary = MigratedRecordsExpected.ENEMY_FACTION_AND_MOVES[id]
		assert_str(enemy.display_name).override_failure_message("%s display_name" % id).is_equal(stats["display_name"])
		assert_int(enemy.max_hp).override_failure_message("%s max_hp" % id).is_equal(stats["max_hp"])
		assert_int(enemy.max_mp).override_failure_message("%s max_mp" % id).is_equal(stats["max_mp"])
		assert_int(enemy.attack).override_failure_message("%s attack" % id).is_equal(stats["attack"])
		assert_int(enemy.defense).override_failure_message("%s defense" % id).is_equal(stats["defense"])
		assert_int(enemy.speed).override_failure_message("%s speed" % id).is_equal(stats["speed"])
		assert_bool(enemy.is_boss).override_failure_message("%s is_boss" % id).is_equal(stats["is_boss"])
		assert_str(enemy.faction_id).override_failure_message("%s faction_id" % id).is_equal(record_only["faction_id"])
		assert_array(Array(enemy.move_ids)).override_failure_message(
				"%s move_ids" % id).is_equal(record_only["move_ids"])
		assert_int(enemy.reward_xp).override_failure_message("%s reward_xp" % id).is_equal(MigratedRecordsExpected.ENEMY_REWARD_XP)
		assert_int(enemy.reward_money).override_failure_message(
				"%s reward_money" % id).is_equal(MigratedRecordsExpected.ENEMY_REWARD_MONEY)
		assert_str(enemy.sprite_set_id).override_failure_message(
				"%s sprite_set_id" % id).is_equal(MigratedRecordsExpected.ENEMY_SPRITE_SET_ID)
		assert_str(enemy.ai_profile_id).override_failure_message(
				"%s ai_profile_id" % id).is_equal(MigratedRecordsExpected.ENEMY_AI_PROFILE_ID)


## Edge case: every move named in story 006's Bureaucratia/MegaCorp
## scenarios maps by name to an ID in that enemy's move_ids (reachability).
func test_enemy_move_ids_cover_every_move_named_in_story_006() -> void:
	var display_name_to_id: Dictionary = {}
	for id: String in MigratedRecordsExpected.NAMED_ATTACKS:
		display_name_to_id[MigratedRecordsExpected.NAMED_ATTACKS[id]["display_name"]] = id

	for id: String in CharacterizationExpected.ENEMY_IDS:
		var move_ids: Array = MigratedRecordsExpected.ENEMY_FACTION_AND_MOVES[id]["move_ids"]
		for scenario: Dictionary in CharacterizationExpected.DAMAGE_CASES["enemy_side"]:
			if scenario["enemy"] != id or scenario["move"] == "attack":
				continue
			var move_id: String = display_name_to_id.get(_move_display_name(scenario["move"]), "")
			assert_bool(move_ids.has(move_id)).override_failure_message(
					"%s: %s not reachable via move_ids %s" % [id, scenario["move"], move_ids]).is_true()


func _move_display_name(move_id: String) -> String:
	return MigratedRecordsExpected.NAMED_ATTACKS.get(move_id, {}).get("display_name", move_id)


# --- Story 017: rule_bureaucratia_permit, rule_megacorp_billing ---

func test_rule_records_load_with_no_error() -> void:
	var catalog := auto_free(ContentCatalogService.new()) as ContentCatalogService
	ContentBootstrap.run(catalog, "res://data")

	for id: String in ["rule_bureaucratia_permit", "rule_megacorp_billing"]:
		var errors: Array[Dictionary] = []
		for entry: Dictionary in catalog.report:
			if entry["severity"] == &"error" and entry["record_id"] == id:
				errors.append(entry)
		assert_int(errors.size()).override_failure_message("%s errors: %s" % [id, errors]).is_equal(0)


func test_rule_contents_match_pinned_table() -> void:
	var catalog := auto_free(ContentCatalogService.new()) as ContentCatalogService
	ContentBootstrap.run(catalog, "res://data")

	var bureaucratia: FactionRuleData = catalog.get_record(&"faction_rule", "rule_bureaucratia_permit")
	assert_object(bureaucratia).is_not_null()
	assert_str(bureaucratia.rule_class).is_equal(MigratedRecordsExpected.BUREAUCRATIA_RULE_CLASS)
	assert_that(bureaucratia.params).override_failure_message(
			"bureaucratia params: %s" % [bureaucratia.params]).is_equal(MigratedRecordsExpected.BUREAUCRATIA_RULE_PARAMS)
	assert_array(Array(bureaucratia.ref_ids)).contains_exactly_in_any_order(
			Array(MigratedRecordsExpected.BUREAUCRATIA_RULE_REF_IDS))
	assert_array(bureaucratia.texts.keys()).contains_exactly_in_any_order(
			Array(MigratedRecordsExpected.BUREAUCRATIA_RULE_TEXT_KEYS))
	assert_array(bureaucratia.colors.keys()).contains_exactly_in_any_order(
			Array(MigratedRecordsExpected.BUREAUCRATIA_RULE_COLOR_KEYS))

	var megacorp: FactionRuleData = catalog.get_record(&"faction_rule", "rule_megacorp_billing")
	assert_object(megacorp).is_not_null()
	assert_str(megacorp.rule_class).is_equal(MigratedRecordsExpected.MEGACORP_RULE_CLASS)
	assert_that(megacorp.params).override_failure_message(
			"megacorp params: %s" % [megacorp.params]).is_equal(MigratedRecordsExpected.MEGACORP_RULE_PARAMS)
	assert_array(Array(megacorp.ref_ids)).contains_exactly_in_any_order(
			Array(MigratedRecordsExpected.MEGACORP_RULE_REF_IDS))
	assert_array(megacorp.texts.keys()).contains_exactly_in_any_order(
			Array(MigratedRecordsExpected.MEGACORP_RULE_TEXT_KEYS))
	assert_bool(megacorp.colors.is_empty()).is_true()


## Edge case: `banner_unlocked` contains "PERMIT GRANTED — All-out war!" exactly.
func test_rule_template_fill_reproduces_pinned_strings() -> void:
	var catalog := auto_free(ContentCatalogService.new()) as ContentCatalogService
	ContentBootstrap.run(catalog, "res://data")
	var bureaucratia: FactionRuleData = catalog.get_record(&"faction_rule", "rule_bureaucratia_permit")
	var megacorp: FactionRuleData = catalog.get_record(&"faction_rule", "rule_megacorp_billing")

	assert_str((bureaucratia.texts["banner_locked_other"] as String).format({"rounds_left": 3})).is_equal(
			CharacterizationExpected.BUREAUCRATIA_BANNER_TEXT[1])
	assert_str((bureaucratia.texts["banner_locked_other"] as String).format({"rounds_left": 2})).is_equal(
			CharacterizationExpected.BUREAUCRATIA_BANNER_TEXT[2])
	assert_str((bureaucratia.texts["banner_locked_one"] as String).format({"rounds_left": 1})).is_equal(
			CharacterizationExpected.BUREAUCRATIA_BANNER_TEXT[3])
	assert_str(bureaucratia.texts["banner_unlocked"]).is_equal(CharacterizationExpected.BUREAUCRATIA_BANNER_TEXT[4])
	assert_str(bureaucratia.texts["banner_unlocked"]).contains("PERMIT GRANTED — All-out war!")
	assert_str(bureaucratia.texts["tooltip_locked"]).is_equal(CharacterizationExpected.BUREAUCRATIA_TOOLTIP_TEXT[1])
	assert_str(bureaucratia.texts["tooltip_unlocked"]).is_equal(CharacterizationExpected.BUREAUCRATIA_TOOLTIP_TEXT[4])
	assert_str(bureaucratia.colors["banner_unlocked"]).is_equal(
			"#" + CharacterizationExpected.BUREAUCRATIA_BANNER_COLOR_HTML[4])

	assert_str((megacorp.texts["banner"] as String).format({"bill_mp": 1})).is_equal(
			CharacterizationExpected.MEGACORP_BANNER_TEXT)
	assert_str((megacorp.texts["tooltip"] as String).format({"bill_mp": 1})).is_equal(
			CharacterizationExpected.MEGACORP_TOOLTIP_TEXT)
	assert_str(megacorp.texts["note_suspended"]).is_equal(CharacterizationExpected.MEGACORP_SUSPENDED_NOTE)


# --- Story 018 (merged with 019): the five squad specials and four characters ---

func test_special_moves_match_shipped_values() -> void:
	for id: String in MigratedRecordsExpected.SPECIAL_MOVE_IDS:
		var move: MoveData = _load("res://data/moves/%s.tres" % id) as MoveData
		assert_object(move).override_failure_message("failed to load %s" % id).is_not_null()

		var pinned: Dictionary = CharacterizationExpected.SPECIALS[id]
		var record_only: Dictionary = MigratedRecordsExpected.SPECIALS_RECORD_ONLY[id]
		assert_str(move.display_name).override_failure_message(
				"%s display_name" % id).is_equal(pinned["display_name"])
		assert_int(move.cost).override_failure_message("%s cost" % id).is_equal(pinned["mp_cost"])
		assert_str(move.target_type).override_failure_message(
				"%s target_type" % id).is_equal(record_only["target_type"])
		assert_array(move.effects).override_failure_message(
				"%s effects" % id).is_equal(record_only["effects"])


## Edge case: "Home Run" is not the prototype's "Baguette Home Run".
func test_home_run_display_name_is_not_prototype_name() -> void:
	var move: MoveData = _load("res://data/moves/move_home_run.tres") as MoveData
	assert_str(move.display_name).is_equal("Home Run")


func test_special_descriptor_types_are_in_battle_effect_types_provisional() -> void:
	for id: String in MigratedRecordsExpected.SPECIAL_MOVE_IDS:
		var move: MoveData = _load("res://data/moves/%s.tres" % id) as MoveData
		var descriptor_type: String = move.effects[0]["type"]
		assert_bool(Array(BattleEffectTypes.PROVISIONAL).has(descriptor_type)).override_failure_message(
				"%s: %s not in BattleEffectTypes.PROVISIONAL" % [id, descriptor_type]).is_true()


## Edge case: no record has a `provisional` property -- a schema change.
func test_special_move_records_have_no_provisional_field() -> void:
	for id: String in MigratedRecordsExpected.SPECIAL_MOVE_IDS:
		var move: MoveData = _load("res://data/moves/%s.tres" % id) as MoveData
		var has_provisional_field := false
		for prop: Dictionary in move.get_property_list():
			if prop["name"] == "provisional":
				has_provisional_field = true
		assert_bool(has_provisional_field).override_failure_message(
				"%s has a provisional field" % id).is_false()


func test_character_records_match_approved_source() -> void:
	var squads: Dictionary = {
		"char_karen": CharacterizationExpected.SQUAD_KAREN,
		"char_michelin_chef": CharacterizationExpected.SQUAD_CHEF,
		"char_florida_man": CharacterizationExpected.SQUAD_FLORIDA_MAN,
		"char_baguette_thrower": CharacterizationExpected.SQUAD_BAGUETTE_THROWER,
	}
	for id: String in MigratedRecordsExpected.CHARACTER_IDS:
		var character: CharacterData = _load("res://data/characters/%s.tres" % id) as CharacterData
		assert_object(character).override_failure_message("failed to load %s" % id).is_not_null()

		var squad: Dictionary = squads[id]
		assert_str(character.display_name).override_failure_message(
				"%s display_name" % id).is_equal(
				MigratedRecordsExpected.RENAMED_DISPLAY_NAMES.get(id, squad["name"]))
		assert_int(character.max_hp).override_failure_message("%s max_hp" % id).is_equal(squad["max_hp"])
		assert_int(character.max_mp).override_failure_message("%s max_mp" % id).is_equal(squad["max_mp"])
		assert_int(character.attack).override_failure_message("%s attack" % id).is_equal(squad["attack"])
		assert_int(character.defense).override_failure_message("%s defense" % id).is_equal(squad["defense"])
		assert_int(character.speed).override_failure_message("%s speed" % id).is_equal(squad["speed"])
		assert_array(Array(character.move_ids)).override_failure_message(
				"%s move_ids" % id).is_equal(MigratedRecordsExpected.CHARACTER_MOVE_IDS[id])
		for field: String in MigratedRecordsExpected.CHARACTER_EMPTY_FIELDS:
			assert_str(character.get(field)).override_failure_message(
					"%s.%s should be empty (Q1, not in REQUIRED_FIELDS)" % [id, field]).is_equal("")
