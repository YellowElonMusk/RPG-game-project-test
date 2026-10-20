## The real battle HUD (Story 005): HP/MP bars per combatant, a banner that
## reads the active faction rule's text, floating damage/heal numbers, and
## hover tooltips explaining the rule. Reads FactionRule's text/color hooks
## (get_banner_text/get_banner_color/get_identity_color/get_tooltip_text/
## get_combatant_tooltip_note) and never branches on which FactionRule
## subclass is active — Bureaucratia and MegaCorp both render through the
## same code path (Acceptance Criterion 6).
##
## Not a scene-tree dependency of BattleCore: this node only listens to its
## signals and reads its public state, so it never mutates battle state
## itself (UI displays state, does not own it).
##
## Usage example:
## [codeblock]
## var hud: BattleHud = preload("res://src/battle/ui/battle_hud.tscn").instantiate()
## add_child(hud)
## hud.setup(battle_core)
## battle_core.start_battle()
## [/codeblock]
class_name BattleHud
extends Control

## Modulate applied to a knocked-out combatant's card (Acceptance Criterion 7).
const KNOCKED_OUT_MODULATE: Color = Color(0.45, 0.45, 0.45)
## Vertical gap between stacked floating numbers so two in flight don't overlap.
const FLOAT_STAGGER_PX: float = 26.0
const FLOAT_RISE_PX: float = 50.0
const FLOAT_RISE_DURATION_SEC: float = 0.9
const FLOAT_FADE_DELAY_SEC: float = 0.5
const FLOAT_FADE_DURATION_SEC: float = 0.5

const COLOR_TEXT: Color = Color("#f2ead8")
const COLOR_HEAL: Color = Color("#7bc96f")
const COLOR_MP: Color = Color("#9fb7ff")
const COLOR_PANEL: Color = Color("#2a2d40")
const COLOR_BG: Color = Color("#1b1d2b")

var _battle: BattleCore
var _ui_built: bool = false

var _banner_panel: PanelContainer
var _banner_label: Label
var _squad_column: VBoxContainer
var _enemy_column: VBoxContainer
var _overlay: Control

## Combatant -> {panel, hp_bar, mp_bar, info_label}. mp_bar is null for an
## enemy card (enemies have no MP — Combatant is always constructed with
## max_mp 0 for them; see BureaucratiaRule/MegaCorpRule's make_* functions).
var _cards: Dictionary = {}
## Combatant -> next float's vertical stagger slot (0, 1, 2, repeating), so
## several floats on the same card don't stack on top of each other.
var _float_slots: Dictionary = {}


## Wires this HUD to a battle: builds one card per squad/enemy member and
## paints the initial banner/card state. Safe to call before or after
## battle.start_battle() — call refresh() afterward if you mutate battle
## state directly rather than through BattleCore's own methods (see
## battle_hud_demo.gd, which forces round_number and a knockout this way for
## screenshot capture).
func setup(battle: BattleCore) -> void:
	_battle = battle
	if not _ui_built:
		_build_static_ui()
		_ui_built = true
	_battle.turn_started.connect(_on_turn_started)
	_battle.action_resolved.connect(_on_action_resolved)
	_battle.round_advanced.connect(_on_round_advanced)
	_battle.battle_ended.connect(_on_battle_ended)
	_build_cards()
	refresh()


## Re-reads every combatant and the faction rule's banner/tooltip text and
## repaints the HUD. Called automatically by this node's own signal
## handlers; exposed publicly for a caller that changes battle state outside
## the normal action flow (see setup()'s doc comment).
func refresh() -> void:
	_refresh_banner()
	_refresh_all_cards()


func _build_static_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_banner_panel = PanelContainer.new()
	root.add_child(_banner_panel)
	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.add_theme_font_size_override("font_size", 20)
	_banner_panel.add_child(_banner_label)

	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 16)
	root.add_child(main_row)

	_squad_column = VBoxContainer.new()
	_squad_column.custom_minimum_size = Vector2(290, 0)
	_squad_column.add_theme_constant_override("separation", 8)
	main_row.add_child(_squad_column)

	_enemy_column = VBoxContainer.new()
	_enemy_column.custom_minimum_size = Vector2(290, 0)
	_enemy_column.add_theme_constant_override("separation", 8)
	main_row.add_child(_enemy_column)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func _build_cards() -> void:
	for child in _squad_column.get_children():
		child.queue_free()
	for child in _enemy_column.get_children():
		child.queue_free()
	_cards.clear()
	_float_slots.clear()
	for combatant in _battle.squad:
		_squad_column.add_child(_make_card(combatant, true))
	for combatant in _battle.enemies:
		_enemy_column.add_child(_make_card(combatant, false))


## `show_mp` is true for squad cards (Acceptance Criterion 2) and false for
## enemy cards — enemies are always constructed with 0 max MP, so an enemy
## MP bar would have nothing to show.
func _make_card(combatant: Combatant, show_mp: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_content_margin_all(10)
	if combatant.is_enemy:
		style.set_border_width_all(3)
		style.border_color = _battle.faction_rule.get_identity_color()
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(box)

	var name_label := Label.new()
	name_label.text = combatant.display_name + ("   (BOSS)" if combatant.is_boss else "")
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	box.add_child(name_label)

	var hp_bar := ProgressBar.new()
	hp_bar.max_value = combatant.max_hp
	hp_bar.value = combatant.hp
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 14)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = _battle.faction_rule.get_identity_color() if combatant.is_enemy else COLOR_HEAL
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	box.add_child(hp_bar)

	var mp_bar: ProgressBar = null
	if show_mp:
		mp_bar = ProgressBar.new()
		mp_bar.max_value = maxi(1, combatant.max_mp)
		mp_bar.value = combatant.mp
		mp_bar.show_percentage = false
		mp_bar.custom_minimum_size = Vector2(0, 10)
		var mp_fill := StyleBoxFlat.new()
		mp_fill.bg_color = COLOR_MP
		mp_bar.add_theme_stylebox_override("fill", mp_fill)
		box.add_child(mp_bar)

	var info_label := Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", COLOR_TEXT)
	box.add_child(info_label)

	_cards[combatant] = {
		"panel": panel, "hp_bar": hp_bar, "mp_bar": mp_bar, "info_label": info_label,
	}
	return panel


func _refresh_all_cards() -> void:
	for combatant in _cards:
		_refresh_card(combatant)


func _refresh_card(combatant: Combatant) -> void:
	var nodes: Dictionary = _cards.get(combatant, {})
	if nodes.is_empty():
		return

	var hp_bar: ProgressBar = nodes["hp_bar"]
	hp_bar.value = combatant.hp
	var mp_bar: ProgressBar = nodes["mp_bar"]
	if mp_bar != null:
		mp_bar.value = combatant.mp

	var knocked_out: bool = combatant.is_knocked_out()
	var info_label: Label = nodes["info_label"]
	if knocked_out:
		info_label.text = "KNOCKED OUT"
	elif mp_bar != null:
		info_label.text = "HP %d/%d   MP %d/%d" % [combatant.hp, combatant.max_hp, combatant.mp, combatant.max_mp]
	else:
		info_label.text = "HP %d/%d" % [combatant.hp, combatant.max_hp]

	var panel: PanelContainer = nodes["panel"]
	panel.modulate = KNOCKED_OUT_MODULATE if knocked_out else Color.WHITE
	panel.tooltip_text = _card_tooltip(combatant)


## Builds a card's tooltip from the faction rule's own text (Acceptance
## Criterion 5) plus this combatant's own state — never a per-faction
## branch here, only faction_rule method calls (Acceptance Criterion 6).
func _card_tooltip(combatant: Combatant) -> String:
	var lines: PackedStringArray = PackedStringArray([combatant.display_name])
	lines.append(_battle.faction_rule.get_tooltip_text(_battle.round_number))
	var note: String = _battle.faction_rule.get_combatant_tooltip_note(combatant)
	if note != "":
		lines.append(note)
	if combatant.is_knocked_out():
		lines.append("Knocked out.")
	return "\n".join(lines)


func _refresh_banner() -> void:
	var round_number: int = _battle.round_number
	_banner_label.text = _battle.faction_rule.get_banner_text(round_number)
	var style := StyleBoxFlat.new()
	style.bg_color = _battle.faction_rule.get_banner_color(round_number)
	style.set_content_margin_all(10)
	_banner_panel.add_theme_stylebox_override("panel", style)
	var tooltip: String = _battle.faction_rule.get_tooltip_text(round_number)
	_banner_panel.tooltip_text = tooltip
	_banner_label.tooltip_text = tooltip


func _on_turn_started(_combatant: Combatant) -> void:
	_refresh_all_cards()


func _on_action_resolved(outcome: BattleOutcome) -> void:
	_refresh_card(outcome.actor)
	if outcome.target != null:
		_refresh_card(outcome.target)
	_spawn_floats(outcome)


func _on_round_advanced(_round_number: int) -> void:
	refresh()


func _on_battle_ended(won: bool) -> void:
	_banner_label.text = "VICTORY!" if won else "DEFEAT"


## Spawns a floating number for MP spent and/or HP changed by one resolved
## action (Acceptance Criterion 4). mp_delta in this codebase is always <= 0
## (MP is only ever spent, never gained by a move — see BattleOutcome's doc
## comment), so no explicit sign formatting is needed for it.
func _spawn_floats(outcome: BattleOutcome) -> void:
	if outcome.mp_delta != 0:
		_float_near(outcome.actor, "%d MP" % outcome.mp_delta, COLOR_MP)
	if outcome.hp_delta != 0:
		var node: Combatant = outcome.target if outcome.target != null else outcome.actor
		var text: String = ("+%d" % outcome.hp_delta) if outcome.hp_delta > 0 else str(outcome.hp_delta)
		var color: Color = COLOR_HEAL if outcome.hp_delta > 0 else COLOR_TEXT
		_float_near(node, text, color)


func _float_near(combatant: Combatant, text: String, color: Color) -> void:
	var nodes: Dictionary = _cards.get(combatant, {})
	if nodes.is_empty():
		return
	var panel: Control = nodes["panel"]

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	_overlay.add_child(label)

	var slot: int = _float_slots.get(combatant, 0)
	_float_slots[combatant] = (slot + 1) % 3
	label.position = panel.global_position + Vector2(panel.size.x * 0.5 - 40, 6 + slot * FLOAT_STAGGER_PX)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - FLOAT_RISE_PX, FLOAT_RISE_DURATION_SEC)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_FADE_DURATION_SEC).set_delay(FLOAT_FADE_DELAY_SEC)
	tween.finished.connect(label.queue_free)
