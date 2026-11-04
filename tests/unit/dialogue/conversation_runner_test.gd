## Dialogue system: `ConversationRunner` walks lines in order, skips lines
## whose flag conditions fail, follows `next_id` and choice jumps, sets flags
## and names squad speakers (skipping members not in the party).
extends GdUnitTestSuite

var _flags: Dictionary = {}


func before_test() -> void:
	_flags = {}


func _has(flag: String) -> bool:
	return _flags.has(flag)


func _set_test_flag(flag: String) -> void:
	_flags[flag] = true


func _line(text: String, extra: Dictionary = {}) -> DialogueLine:
	var line := DialogueLine.new()
	line.text = text
	for key: String in extra:
		line.set(key, extra[key])
	return line


func _choice(label: String, goto_id: String, sets_flag: String = "") -> DialogueChoice:
	var choice := DialogueChoice.new()
	choice.label = label
	choice.goto_id = goto_id
	choice.sets_flag = sets_flag
	return choice


func _talk(lines: Array[DialogueLine]) -> Conversation:
	var talk := Conversation.new()
	talk.id = "conv_test"
	talk.lines = lines
	return talk


func _run(talk: Conversation, names: Callable = Callable()) -> ConversationRunner:
	return ConversationRunner.new(talk, _has, _set_test_flag, names)


func test_lines_play_in_order_then_finish() -> void:
	var run := _run(_talk([_line("one"), _line("two"), _line("three")]))
	var seen: PackedStringArray = []
	while not run.is_finished():
		seen.append(run.text())
		run.advance()
	assert_array(Array(seen)).is_equal(["one", "two", "three"])


func test_requires_and_skip_if_flag_conditions() -> void:
	var talk := _talk([
		_line("always"),
		_line("only with flag", {"requires_flag": "met"}),
		_line("only without flag", {"skip_if_flag": "met"}),
	])
	var first := _run(talk)
	first.advance()
	assert_str(first.text()).is_equal("only without flag")
	_set_test_flag("met")
	var second := _run(talk)
	second.advance()
	assert_str(second.text()).is_equal("only with flag")
	second.advance()
	assert_bool(second.is_finished()).is_true()


func test_next_id_jumps_and_end_finishes() -> void:
	var run := _run(_talk([
		_line("start", {"next_id": "later"}),
		_line("skipped"),
		_line("later", {"id": "later", "next_id": "end"}),
		_line("never"),
	]))
	run.advance()
	assert_str(run.text()).is_equal("later")
	run.advance()
	assert_bool(run.is_finished()).is_true()


func test_choice_sets_flag_and_jumps() -> void:
	var ask := _line("tip?")
	ask.choices.assign([_choice("yes", "tip", "heard_tip"), _choice("no", "bye")])
	var talk := _talk([ask, _line("the tip", {"id": "tip", "next_id": "end"}), _line("bye", {"id": "bye"})])
	var yes := _run(talk)
	assert_int(yes.choices().size()).is_equal(2)
	yes.advance()  # a line with choices waits for choose()
	assert_str(yes.text()).is_equal("tip?")
	yes.choose(0)
	assert_str(yes.text()).is_equal("the tip")
	assert_bool(_has("heard_tip")).is_true()
	assert_array(Array(yes.flags_set)).is_equal(["heard_tip"])

	_flags = {}
	var no := _run(talk)
	no.choose(1)
	assert_str(no.text()).is_equal("bye")
	assert_bool(_has("heard_tip")).is_false()


func test_line_sets_flag_when_shown() -> void:
	var run := _run(_talk([_line("hello", {"sets_flag": "greeted"})]))
	assert_bool(_has("greeted")).is_true()
	run.advance()
	assert_bool(run.is_finished()).is_true()


func test_squad_speaker_named_or_skipped() -> void:
	var talk := _talk([
		_line("hi", {"speaker_id": "char_karen", "speaker": "Fallback"}),
		_line("absent", {"speaker_id": "char_nobody", "speaker": "Nobody"}),
		_line("narrator"),
	])
	var names := func(char_id: String) -> String:
		return "Karen" if char_id == "char_karen" else ""
	var run := _run(talk, names)
	assert_str(run.speaker()).is_equal("Karen")
	run.advance()
	assert_str(run.text()).is_equal("narrator")
	assert_str(run.speaker()).is_equal("")
	# Without a name lookup every line plays and shows its fallback name.
	var plain := _run(talk)
	plain.advance()
	assert_str(plain.speaker()).is_equal("Nobody")


func test_unknown_goto_and_loops_end_safely() -> void:
	var loop := _run(_talk([_line("a", {"id": "a", "next_id": "a"})]))
	for i: int in ConversationRunner.MAX_STEPS + 2:
		loop.advance()
	assert_bool(loop.is_finished()).is_true()


func test_single_line_conversation() -> void:
	var run := _run(Conversation.single("Mind the queue.", "Café regular"))
	assert_str(run.text()).is_equal("Mind the queue.")
	assert_str(run.speaker()).is_equal("Café regular")
	run.advance()
	assert_bool(run.is_finished()).is_true()


func test_shipped_conversations_load_and_jump_targets_exist() -> void:
	var dir := DirAccess.open(Conversation.DIR)
	assert_object(dir).is_not_null()
	var count: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var talk: Conversation = Conversation.load_by_id(file.get_basename())
		assert_object(talk).override_failure_message("%s does not load" % file).is_not_null()
		assert_str(talk.id).is_equal(file.get_basename())
		count += 1
		for line: DialogueLine in talk.lines:
			assert_int(line.text.length()).override_failure_message(
					"%s: line over 120 characters: %s" % [talk.id, line.text]).is_less_equal(120)
			var targets: PackedStringArray = [line.next_id]
			for choice: DialogueChoice in line.choices:
				targets.append(choice.goto_id)
			for target: String in targets:
				if target.is_empty() or target == ConversationRunner.END:
					continue
				assert_int(talk.index_of(target)).override_failure_message(
						"%s jumps to missing line %s" % [talk.id, target]).is_greater_equal(0)
	assert_int(count).is_greater_equal(7)
