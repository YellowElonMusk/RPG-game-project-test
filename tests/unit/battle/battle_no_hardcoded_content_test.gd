## Content-migration story 030 (merged 031, 032; ADR-0001 / ADR-0011 Migration
## Step 4; RC-7): the battle content scripts declare no content constants and
## carry none of the pinned player-visible strings as literals. The forbidden
## display strings are read from `CharacterizationExpected`, so the list
## cannot drift from what Step 0 pinned.
##
## Implemented so far: the specials case (story 032). The Bureaucratia (030)
## and MegaCorp (031) cases wait on stories 026/027, which are blocked.
extends GdUnitTestSuite

const _SPECIALS_PATH: String = "res://src/battle/squad/specials.gd"
const _SRC_ROOT: String = "res://src"

## Story 032 AC-1: the nine deleted special const names (pinned by the story).
const _DELETED_SPECIAL_CONSTS: Array[String] = [
	"SPEAK_TO_MANAGER_MP_COST", "APPETIZER_MP_COST", "APPETIZER_POWER",
	"FAMILY_MEAL_MP_COST", "FAMILY_MEAL_POWER", "VIRAL_STUNT_MP_COST",
	"VIRAL_STUNT_ROUNDS", "HOME_RUN_MP_COST", "HOME_RUN_POWER",
]


func test_specials_declares_no_deleted_const_names() -> void:
	var text: String = _read(_SPECIALS_PATH)
	for const_name: String in _DELETED_SPECIAL_CONSTS:
		assert_bool(text.contains(const_name)).override_failure_message(
				"specials.gd still mentions %s" % const_name).is_false()


func test_specials_contains_no_shipped_special_name_literal() -> void:
	var text: String = _read(_SPECIALS_PATH)
	assert_int(CharacterizationExpected.SPECIALS.size()).is_equal(5)
	for record_id: String in CharacterizationExpected.SPECIALS:
		var display: String = CharacterizationExpected.SPECIALS[record_id]["display_name"]
		var quoted: String = "\"%s\"" % display
		assert_bool(text.contains(quoted)).override_failure_message(
				"specials.gd has the literal %s" % quoted).is_false()


func test_specials_keeps_heal_attack_scale_for_stats_epic() -> void:
	# Edge case: HEAL_ATTACK_SCALE moves with ADR-0007 Migration Step 2, not here.
	var text: String = _read(_SPECIALS_PATH)
	assert_bool(text.contains("const HEAL_ATTACK_SCALE")).is_true()


func test_src_mentions_no_deleted_special_const_name() -> void:
	var files: Array[String] = []
	_collect_gd_files(_SRC_ROOT, files)
	assert_bool(files.is_empty()).override_failure_message("no .gd files under src/").is_false()
	for path: String in files:
		var text: String = _read(path)
		for const_name: String in _DELETED_SPECIAL_CONSTS:
			assert_bool(text.contains(const_name)).override_failure_message(
					"%s still mentions %s" % [path, const_name]).is_false()


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_object(file).override_failure_message("cannot open %s" % path).is_not_null()
	if file == null:
		return ""
	return file.get_as_text()


func _collect_gd_files(dir_path: String, out: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		_collect_gd_files(dir_path.path_join(sub), out)
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			out.append(dir_path.path_join(file_name))
