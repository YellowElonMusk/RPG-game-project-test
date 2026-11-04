## INTERIM Menu overlay (ADR-0002 §5-§6; story 029's `MenuPayload`): a
## centred navy/cream window listing exactly the payload's entries, over a
## light dim. "Resume" closes the Menu, and "Quit to Title" requests Title
## (legal while the Menu is on top). Party, Codex and Settings are shown
## disabled until their screens exist. Cancel closes the Menu; the menu key
## does too, handled by the machine.
##
## It exists because the overlay had no scene at all: focus loss or the menu
## key pushed a MENU entry with nothing behind it, the mode clock froze, and
## every press was dropped, so the game soft-locked. Stands in for the UI
## Framework's Menu screen (ADR-0008), with the same INTERIM focus handling
## as `DefeatPrompt`.
class_name InterimMenu extends GameOverlay

## Entry id -> [label, enabled].
const ENTRIES: Dictionary = {
	&"pause": ["Resume", true],
	&"party": ["Party (coming soon)", false],
	&"codex": ["Codex (coming soon)", false],
	&"settings": ["Settings (coming soon)", false],
	&"quit": ["Quit to Title", true],
	&"items": ["Items", true],
}
const COLOR_BACKING: Color = Color("#2a2d40")
const COLOR_BORDER: Color = Color("#f2ead8")
## The world dim behind the window (the Menu backdrop source, ADR-0005 §12).
const DIM: Color = Color(0.0, 0.0, 0.0, 0.35)

var _machine: GameStateMachine = null
var _entries: Array[StringName] = []
var _buttons: Array[Button] = []
var _button_by_entry: Dictionary[StringName, Button] = {}
## Items & Shops OQ-2: using items outside battle. GameRoot's overlay
## pre-setup injects these outside Battle; with all three set, the Menu
## shows an Items entry under Resume (not a payload entry, so `entries()`
## stays the exact AC-31 list).
var world_state: WorldState = null
var item_catalog: Object = null
var party: Array[Combatant] = []
var _box: VBoxContainer = null
## `main`, `items`, `targets`, `party`, `member` or `slot`: which list is
## showing (cancel steps back one level).
var _screen: StringName = &"main"
## The member the equipment screens are showing.
var _member: Combatant = null
var _title: Label = null
## The line under the list on the Items screens ("" = none).
var _note: Label = null


func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	var menu_payload := payload as MenuPayload
	if menu_payload != null:
		_entries.assign(menu_payload.entries)
	else:
		_entries.assign([&"pause", &"quit"])
	_build()


## The entry ids shown, in order (tests).
func entries() -> Array[StringName]:
	return _entries


## The button for `entry`, or null (tests).
func button_for(entry: StringName) -> Button:
	return _button_by_entry.get(entry, null)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BACKING
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.custom_minimum_size = Vector2(260, 0)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override(&"separation", 8)
	panel.add_child(outer)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 22)
	_title.add_theme_color_override(&"font_color", COLOR_BORDER)
	outer.add_child(_title)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 8)
	outer.add_child(_box)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(260, 0)
	_note.add_theme_color_override(&"font_color", COLOR_BORDER)
	outer.add_child(_note)
	_show_main()


## The main list: Resume (always first), Items when the bag is wired, then
## the payload's entries.
func _show_main() -> void:
	_screen = &"main"
	_title.text = "Paused"
	_note.text = ""
	_reset_list()
	var box: VBoxContainer = _box
	# A Menu without "pause" (Battle: settings, quit) still opens on Resume,
	# never on Quit to Title: the safe default focus (GDD rule 9). Resume is
	# not a payload entry, so `entries()` stays the exact AC-31 list.
	var shown: Array[StringName] = _entries.duplicate()
	if not shown.has(&"pause"):
		shown.push_front(&"pause")
	if has_items_entry():
		shown.insert(1, &"items")
	for entry: StringName in shown:
		var spec: Array = ENTRIES.get(entry, [String(entry).capitalize(), false])
		var button := Button.new()
		button.text = spec[0]
		button.disabled = not bool(spec[1])
		if entry == &"party" and has_items_entry():
			button.text = "Party"
			button.disabled = false
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_entry.bind(entry))
		box.add_child(button)
		_buttons.append(button)
		_button_by_entry[entry] = button
	_wire_and_focus()


## `true` when the Menu offers Items (outside Battle, with the bag wired).
func has_items_entry() -> bool:
	return world_state != null and item_catalog != null and not party.is_empty()


## The bag: one row per usable record with its count; an item no one needs
## right now is disabled (rule 6). Cancel returns to the main list.
func _show_items(note: String = "") -> void:
	_screen = &"items"
	_title.text = "Items"
	_note.text = note
	_reset_list()
	var moves: Array[Move] = _item_moves()
	if moves.is_empty():
		_note.text = "The bag is empty. The café sells snacks."
	for move: Move in moves:
		var targets: Array[Combatant] = _targets_for(move)
		var button := _add_button("%s x%d" % [move.display_name, world_state.inventory.count(move.item_id)]
				+ ("" if not targets.is_empty() else " -- no one needs it"))
		button.disabled = targets.is_empty()
		button.pressed.connect(_on_item.bind(move))
	_wire_and_focus()


## Who `move` can be used on: the members it would help (a party item: a
## single "Everyone" row when it would help anyone).
func _show_targets(move: Move) -> void:
	_screen = &"targets"
	_title.text = "%s -- on whom?" % move.display_name
	_note.text = ""
	_reset_list()
	for c: Combatant in _targets_for(move):
		var button := _add_button("%s  HP %d/%d  MP %d/%d" % [c.display_name, c.hp, c.max_hp, c.mp, c.max_mp])
		button.pressed.connect(_use.bind(move, c))
	_wire_and_focus()


func _on_item(move: Move) -> void:
	if move.target_type == Move.TargetType.SELF:
		_use(move, null)
	else:
		_show_targets(move)


## Spends one and applies it (the same `ItemEffects` battle uses), then
## returns to the bag with what it did.
func _use(move: Move, target: Combatant) -> void:
	if not ItemEffects.has_effect(move, target, party) or not world_state.inventory.remove(move.item_id):
		_show_items()
		return
	var living: Array[Combatant] = []
	for c: Combatant in party:
		if not c.is_knocked_out():
			living.append(c)
	ItemEffects.apply(move, target, living)
	_show_items("Used %s%s." % [move.display_name, "" if target == null else " on " + target.display_name])


## Items & Shops rules 10-12: the squad with level and stats (gear bonus in
## brackets); choosing a member opens their slots.
func _show_party(note: String = "") -> void:
	_screen = &"party"
	_title.text = "Party"
	_note.text = note
	_reset_list()
	for c: Combatant in party:
		var button := _add_button("%s%s  Lv %d  HP %d/%d  MP %d/%d\nATK %d%s  DEF %d%s  SPD %d" % [
				"[Bench] " if is_benched(c) else "", c.display_name, c.level, c.hp, c.max_hp, c.mp, c.max_mp,
				c.effective_attack(), _bonus(c.bonus_attack), c.effective_defense(), _bonus(c.bonus_defense), c.speed])
		button.pressed.connect(_show_member.bind(c))
	_wire_and_focus()


## `true` when `c` is on the bench: past the first `SquadStore.ACTIVE_SIZE`.
func is_benched(c: Combatant) -> bool:
	return party.find(c) >= SquadStore.ACTIVE_SIZE


## `member`'s slots, each with what it wears, then "Swap with..." when the
## roster has a bench.
func _show_member(member: Combatant, note: String = "") -> void:
	_screen = &"member"
	_member = member
	_title.text = "%s -- equipment" % member.display_name
	_note.text = note
	_reset_list()
	for slot: StringName in Equipment.SLOTS:
		var worn: ItemData = _record(String(member.equipment.get(slot, "")))
		var text: String = "%s: %s" % [Equipment.SLOT_NAMES[slot],
				"--" if worn == null else "%s (%s)" % [worn.display_name, Equipment.bonus_text(worn)]]
		var button := _add_button(text)
		button.pressed.connect(_show_slot.bind(member, slot))
	if party.size() > SquadStore.ACTIVE_SIZE:
		var swap := _add_button("Send to the bench..." if not is_benched(member) else "Bring into the party...")
		swap.pressed.connect(_show_swap.bind(member))
	_wire_and_focus()


## Who `member` can trade places with: the bench for a fighter, the
## fighters for a benched member.
func _show_swap(member: Combatant) -> void:
	_screen = &"swap"
	_member = member
	_title.text = "%s -- swap with whom?" % member.display_name
	_note.text = ""
	_reset_list()
	for c: Combatant in party:
		if c == member or is_benched(c) == is_benched(member):
			continue
		var button := _add_button("%s  Lv %d  HP %d/%d" % [c.display_name, c.level, c.hp, c.max_hp])
		button.pressed.connect(_swap.bind(member, c))
	_wire_and_focus()


## Trades `a` and `b`'s roster places in the shared array. Refused when it
## would leave nobody standing in the party.
func _swap(a: Combatant, b: Combatant) -> void:
	var ia: int = party.find(a)
	var ib: int = party.find(b)
	SquadStore.swap_in(party, ia, ib)
	var standing: bool = false
	for i: int in mini(SquadStore.ACTIVE_SIZE, party.size()):
		standing = standing or not party[i].is_knocked_out()
	if not standing:
		SquadStore.swap_in(party, ia, ib)
		_show_member(a, "Someone still standing has to fight.")
		return
	_show_party("%s and %s swapped places." % [a.display_name, b.display_name])


## What `member` can put in `slot`: every fitting item in the bag, plus
## "Take off" when the slot is filled.
func _show_slot(member: Combatant, slot: StringName) -> void:
	_screen = &"slot"
	_member = member
	_title.text = "%s -- %s" % [member.display_name, Equipment.SLOT_NAMES[slot]]
	_note.text = ""
	_reset_list()
	for id: String in world_state.inventory.ids():
		var rec: ItemData = _record(id)
		if rec == null or Equipment.slot_of(rec) != slot or not Equipment.fits(member, rec):
			continue
		var button := _add_button("%s (%s) x%d" % [rec.display_name, Equipment.bonus_text(rec), world_state.inventory.count(id)])
		button.pressed.connect(_equip.bind(member, rec))
	if member.equipment.has(slot):
		var off := _add_button("Take off")
		off.pressed.connect(_unequip.bind(member, slot))
	if _buttons.is_empty():
		_note.text = "Nothing in the bag fits. The café sells gear."
	_wire_and_focus()


func _equip(member: Combatant, rec: ItemData) -> void:
	var ok: bool = Equipment.equip(member, rec, world_state.inventory, item_catalog)
	_show_member(member, ("%s equipped %s." % [member.display_name, rec.display_name]) if ok else "The bag is too full to swap.")


func _unequip(member: Combatant, slot: StringName) -> void:
	var ok: bool = Equipment.unequip(member, slot, world_state.inventory, item_catalog)
	_show_member(member, "Back in the bag." if ok else "The bag is too full.")


func _record(id: String) -> ItemData:
	if id.is_empty() or item_catalog == null:
		return null
	return item_catalog.call(&"get_record", &"item", id) as ItemData


static func _bonus(n: int) -> String:
	return "" if n == 0 else " (%+d)" % n


func _item_moves() -> Array[Move]:
	var out: Array[Move] = []
	for id: String in world_state.inventory.ids():
		var move: Move = ItemEffects.move_for(item_catalog.call(&"get_record", &"item", id) as ItemData)
		if move != null:
			out.append(move)
	return out


func _targets_for(move: Move) -> Array[Combatant]:
	var out: Array[Combatant] = []
	if move.target_type == Move.TargetType.SELF:
		if ItemEffects.has_effect(move, null, party):
			out.append_array(party)
		return out
	for c: Combatant in party:
		if ItemEffects.has_effect(move, c, party):
			out.append(c)
	return out


func _reset_list() -> void:
	for b: Button in _buttons:
		_box.remove_child(b)
		b.queue_free()
	_buttons.clear()
	_button_by_entry.clear()


func _add_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	_box.add_child(button)
	_buttons.append(button)
	return button


func _wire_and_focus() -> void:
	for i: int in _buttons.size():
		var up: NodePath = _buttons[i].get_path_to(_buttons[i - 1]) if i > 0 else NodePath()
		var down: NodePath = _buttons[i].get_path_to(_buttons[i + 1]) if i < _buttons.size() - 1 else NodePath()
		_buttons[i].focus_neighbor_top = up
		_buttons[i].focus_neighbor_bottom = down
	if is_inside_tree():
		_ready()


## INTERIM (as `DefeatPrompt._ready()`): focuses the first enabled entry.
func _ready() -> void:
	for button: Button in _buttons:
		if not button.disabled:
			button.grab_focus()
			return


## `true` = consumed. Cancel closes the Menu; Confirm and directions route
## through `InterimFocusNav`; everything else is consumed and ignored.
func handle_action(action: StringName, pressed: bool) -> bool:
	if not pressed:
		return true
	match action:
		InputActions.CANCEL:
			if _screen == &"targets":
				_show_items()
			elif _screen == &"slot" or _screen == &"swap":
				_show_member(_member)
			elif _screen == &"member":
				_show_party()
			elif _screen == &"items" or _screen == &"party":
				_show_main()
			else:
				_close()
		InputActions.CONFIRM:
			InterimFocusNav.route_confirm(self)
		InputActions.NAV_UP:
			InterimFocusNav.route_direction(self, SIDE_TOP)
		InputActions.NAV_DOWN:
			InterimFocusNav.route_direction(self, SIDE_BOTTOM)
	return true


func _on_entry(entry: StringName) -> void:
	match entry:
		&"pause":
			_close()
		&"items":
			_show_items()
		&"party":
			_show_party()
		&"quit":
			if _machine != null:
				_machine.request_transition(GameStateMachine.Mode.TITLE)


func _close() -> void:
	if _machine != null:
		_machine.close_overlay()
