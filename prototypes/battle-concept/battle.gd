# PROTOTYPE - NOT FOR PRODUCTION
# Question (iteration 3): With the brief's latest changes (the Chef's single-target
#   Appetizer, and a second faction, MegaCorp, whose subscription billing drains MP
#   every round and suspends you to basic attacks at 0 MP), does each planet's rule
#   make its fight play differently?
# Date: 2026-10-20
extends Control

# --- Tuning (hardcoded on purpose: this is a throwaway prototype) ---
const POWER_SCALE = 10.0        # S&D F3: power 10 = basic attack
const HEAL_ATTACK_SCALE = 50.0  # S&D F4
const VARIANCE = 0.10           # S&D F6: +/-10% on damage
const DAMAGE_CAP = 999          # S&D F7
const MULT_MIN = 0.1            # S&D F5
const MULT_MAX = 3.0
const PERMIT_ROUNDS = 3         # Bureaucratia: specials banned for this many rounds
const BILL_MP = 2               # MegaCorp: MP billed to every squad member each round
const DEFEND_PCT = -0.5         # Defending: take half damage
const VIRAL_PCT = 0.5           # Gone Viral: take +50% damage
const LOW_HP = 0.5              # Bureaucratia goes for anyone at or below half HP

const C_BG = Color("#1b1d2b")
const C_PANEL = Color("#2a2d40")
const C_ACTIVE = Color("#4a5a8a")
const C_STAMP_RED = Color("#D23A2E")   # Bureaucratia (art bible)
const C_CYAN = Color("#19C2D6")        # MegaCorp Terminal Cyan (art bible)
const C_WAR = Color("#b07a12")
const C_HEAL = Color("#7bc96f")
const C_TEXT = Color("#f2ead8")
const C_DARK = Color("#111320")
const C_MP = Color("#9fb7ff")
const C_QUIRK = Color("#f2c14e")

const STATE_INFO = {
	"Defending": "Hunkered down. Takes half damage until its next turn.",
	"Stunned": "Speechless after a complaint. Loses its next turn.",
	"Gone Viral": "Everyone is watching. Takes 50% more damage.",
	"Regen": "Well fed. Recovers HP at the end of each round.",
}

var rng = RandomNumberGenerator.new()
var faction = ""  # "bureaucratia" or "megacorp"
var squad = []
var enemies = []
var round_no = 1
var actor_idx = 0
var pending_move = {}
var busy = false
var battle_over = false
var autoplay = false  # dev-only: `-- --autoplay [--naive] [--faction=...]` plays a whole fight

# Playtest instrumentation
var attacks_pending = 0
var defends_pending = 0
var hp_pct_at_permit = -1
var specials_used = 0
var stuns_landed = 0
var boss_complaints = 0
var healed_total = 0
var mp_billed = 0
var suspended_turns = 0

# UI references
var chooser
var log_box
var command_bar
var prompt_label
var overlay
var banner_panel
var banner_label


func _ready():
	rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var args = OS.get_cmdline_user_args()
	autoplay = args.has("--autoplay")
	if autoplay:
		Engine.time_scale = 6.0
	var picked = ""
	for a in args:
		if a.begins_with("--faction="):
			picked = a.trim_prefix("--faction=")
	if picked == "bureaucratia" or picked == "megacorp":
		_start_battle(picked)
	else:
		_show_chooser()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _specials_allowed():
	if faction == "bureaucratia":
		return round_no > PERMIT_ROUNDS
	return true


func _is_suspended(c):
	return faction == "megacorp" and not c["is_enemy"] and c["mp"] <= 0


func _hp_pct(c):
	return float(c["hp"]) / float(c["max_hp"])


# ---------------------------------------------------------------- planet chooser

func _show_chooser():
	chooser = Control.new()
	chooser.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(chooser)
	var bg = ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	chooser.add_child(bg)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	chooser.add_child(center)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)

	var title = Label.new()
	title.text = "Go back to your planet!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", C_TEXT)
	v.add_child(title)
	var sub = Label.new()
	sub.text = "Battle prototype — choose a planet to liberate"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", C_TEXT)
	v.add_child(sub)

	var b1 = Button.new()
	b1.text = "Bureaucratia — the permit planet"
	b1.custom_minimum_size = Vector2(460, 56)
	b1.tooltip_text = "No special moves for either side until the government permit arrives (3 rounds)."
	b1.pressed.connect(_on_pick.bind("bureaucratia"))
	v.add_child(b1)
	var b2 = Button.new()
	b2.text = "MegaCorp — the cyberpunk planet"
	b2.custom_minimum_size = Vector2(460, 56)
	b2.tooltip_text = "Subscription billing: every squad member pays MP each round. At 0 MP you're suspended."
	b2.pressed.connect(_on_pick.bind("megacorp"))
	v.add_child(b2)
	b1.grab_focus()


func _on_pick(f):
	chooser.queue_free()
	chooser = null
	_start_battle(f)


func _start_battle(f):
	faction = f
	_make_data()
	_build_ui()
	_update_rule_banner()
	if faction == "bureaucratia":
		_log("[b]The Permit Office.[/b] Three Bureaucratia officials block the road.")
		_log("[color=#D23A2E]BUREAUCRATIA RULE: No special moves for either side until the government permit arrives (3 rounds). Attack and Defend only.[/color]")
	else:
		_log("[b]MegaCorp Tower, floor 404.[/b] Security drones, a middle manager, and the CEO himself.")
		_log("[color=#19C2D6]MEGACORP RULE: Subscription billing. Every squad member is charged %d MP at the end of each round. At 0 MP you're SUSPENDED: basic Attack only.[/color]" % BILL_MP)
	_log("[i]Hover over cards and buttons for details. Press R at any time to go back to the planet select.[/i]")
	_log("[b]— Round 1 —[/b]")
	_start_actor_turn()


# ---------------------------------------------------------------- data

func _mk(display_name, hp, mp, atk, def, spd, is_enemy, moves):
	return {
		"name": display_name, "max_hp": hp, "hp": hp, "max_mp": mp, "mp": mp,
		"atk": atk, "def": def, "spd": spd, "is_enemy": is_enemy, "is_boss": false,
		"states": {}, "moves": moves, "regen_amt": 0,
	}


func _make_data():
	var attack = {"name": "Attack", "cost": 0, "kind": "damage", "power": 10,
		"target": "enemy", "special": false, "desc": "A basic attack."}
	var defend = {"name": "Defend", "cost": 0, "kind": "defend",
		"target": "self", "special": false, "desc": "Hunker down: take half damage until your next turn."}
	squad = [
		_mk("Karen", 34, 12, 12, 9, 11, false, [attack, defend,
			{"name": "Speak to the Manager", "cost": 4, "kind": "stun", "target": "enemy", "special": true,
			"desc": "Stun one enemy for 1 turn. Doesn't work on bosses."}]),
		_mk("Michelin Chef", 30, 14, 11, 7, 10, false, [attack, defend,
			{"name": "Appetizer", "cost": 3, "kind": "heal", "target": "ally", "special": true,
			"power": 10, "desc": "Plate a little something for one ally: heals them right away."},
			{"name": "Family Meal", "cost": 5, "kind": "regen", "target": "allies", "special": true,
			"power": 5, "turns": 3,
			"desc": "Cook for the whole squad: every ally regenerates HP at the end of each round for 3 rounds."}]),
		_mk("Florida Man", 38, 10, 14, 8, 12, false, [attack, defend,
			{"name": "Viral Stunt", "cost": 3, "kind": "viral", "target": "enemy", "special": true,
			"turns": 2,
			"desc": "Film something unbelievable next to one enemy: it takes 50% more damage for 2 rounds."}]),
		_mk("Baguette Thrower", 32, 12, 15, 7, 13, false, [attack, defend,
			{"name": "Baguette Home Run", "cost": 4, "kind": "damage", "power": 18, "target": "enemy",
			"special": true, "desc": "Swing a day-old baguette like a baseball bat. (Power 18)"}]),
	]
	if faction == "bureaucratia":
		enemies = [
			_mk("Clerk A", 40, 0, 11, 6, 8, true, []),
			_mk("Clerk B", 40, 0, 11, 6, 8, true, []),
			_mk("Supervisor", 110, 0, 15, 10, 9, true, []),
		]
	else:
		enemies = [
			_mk("Security Drone", 36, 0, 12, 8, 10, true, []),
			_mk("Middle Manager", 44, 0, 10, 6, 8, true, []),
			_mk("CEO", 120, 0, 15, 10, 9, true, []),
		]
	enemies[2]["is_boss"] = true


# ---------------------------------------------------------------- UI

func _box(fill, border = Color(0, 0, 0, 0)):
	var sb = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_content_margin_all(10)
	if border.a > 0.0:
		sb.set_border_width_all(3)
		sb.border_color = border
	return sb


func _faction_color():
	return C_STAMP_RED if faction == "bureaucratia" else C_CYAN


func _build_ui():
	var bg = ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	banner_panel = PanelContainer.new()
	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_label.add_theme_font_size_override("font_size", 20)
	banner_panel.add_child(banner_label)
	root.add_child(banner_panel)

	var main = HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 16)
	root.add_child(main)

	var squad_col = VBoxContainer.new()
	squad_col.custom_minimum_size = Vector2(290, 0)
	squad_col.add_theme_constant_override("separation", 8)
	main.add_child(squad_col)
	for i in squad.size():
		squad_col.add_child(_make_card(squad[i], i))

	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_theme_font_size_override("normal_font_size", 16)
	log_box.add_theme_font_size_override("bold_font_size", 16)
	log_box.add_theme_font_size_override("italics_font_size", 16)
	main.add_child(log_box)

	var enemy_col = VBoxContainer.new()
	enemy_col.custom_minimum_size = Vector2(290, 0)
	enemy_col.add_theme_constant_override("separation", 8)
	main.add_child(enemy_col)
	for i in enemies.size():
		enemy_col.add_child(_make_card(enemies[i], i))

	prompt_label = Label.new()
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_color_override("font_color", C_TEXT)
	root.add_child(prompt_label)

	command_bar = HBoxContainer.new()
	command_bar.add_theme_constant_override("separation", 10)
	command_bar.custom_minimum_size = Vector2(0, 52)
	root.add_child(command_bar)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)


func _update_rule_banner():
	if faction == "megacorp":
		banner_label.text = "MEGACORP:   Subscription billing. Every squad member pays %d MP at the end of each round. At 0 MP you're SUSPENDED: basic Attack only." % BILL_MP
		banner_label.add_theme_color_override("font_color", C_DARK)
		banner_panel.add_theme_stylebox_override("panel", _box(C_CYAN))
	elif _specials_allowed():
		banner_label.text = "PERMIT GRANTED:   All-out war! Special moves allowed for both sides."
		banner_label.add_theme_color_override("font_color", C_TEXT)
		banner_panel.add_theme_stylebox_override("panel", _box(C_WAR))
	else:
		var left = PERMIT_ROUNDS - round_no + 1
		banner_label.text = "BUREAUCRATIA:   Special moves need a government permit — it arrives in %d round%s. Attack and Defend only, for both sides." % [left, "" if left == 1 else "s"]
		banner_label.add_theme_color_override("font_color", C_TEXT)
		banner_panel.add_theme_stylebox_override("panel", _box(C_STAMP_RED))


func _make_card(c, i):
	var panel = PanelContainer.new()
	var v = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(v)

	var name_label = Label.new()
	name_label.text = c["name"] + ("   (BOSS)" if c["is_boss"] else "")
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", C_TEXT)
	v.add_child(name_label)

	var bar = ProgressBar.new()
	bar.max_value = c["max_hp"]
	bar.value = c["hp"]
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	var fill = StyleBoxFlat.new()
	fill.bg_color = _faction_color() if c["is_enemy"] else C_HEAL
	var empty = StyleBoxFlat.new()
	empty.bg_color = C_DARK
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", empty)
	v.add_child(bar)

	var info = Label.new()
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", C_TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)

	var btn = Button.new()
	btn.text = "Target"
	btn.disabled = true
	btn.pressed.connect(_on_target.bind(c["is_enemy"], i))
	v.add_child(btn)

	c["panel"] = panel
	c["hp_bar"] = bar
	c["info"] = info
	c["button"] = btn
	_restyle(c, false)
	_refresh(c)
	return panel


func _restyle(c, active):
	if c["is_enemy"]:
		c["panel"].add_theme_stylebox_override("panel", _box(C_PANEL, _faction_color()))
	else:
		c["panel"].add_theme_stylebox_override("panel", _box(C_ACTIVE if active else C_PANEL))


func _refresh(c):
	c["hp_bar"].value = c["hp"]
	var lines = PackedStringArray()
	if c["hp"] <= 0:
		lines.append("KNOCKED OUT")
	elif not c["is_enemy"]:
		lines.append("HP %d/%d    MP %d/%d" % [c["hp"], c["max_hp"], c["mp"], c["max_mp"]])
	var tags = PackedStringArray()
	if c["hp"] > 0 and _is_suspended(c):
		tags.append("SUSPENDED")
	for s in c["states"]:
		if s in ["Gone Viral", "Regen"]:
			tags.append("%s (%d)" % [s, c["states"][s]])
		else:
			tags.append(s)
	if tags.size() > 0:
		lines.append(", ".join(tags))
	c["info"].text = "\n".join(lines)

	var tip = c["name"]
	if c["is_enemy"]:
		tip += " — Bureaucratia official." if faction == "bureaucratia" else " — MegaCorp asset."
		if c["is_boss"]:
			tip += "\nBoss: immune to complaints."
	elif _is_suspended(c):
		tip += "\nSUSPENDED: out of MP. Basic Attack only until you have MP again."
	for s in c["states"]:
		tip += "\n" + s + ": " + STATE_INFO[s]
	c["panel"].tooltip_text = tip

	c["panel"].modulate = Color(0.45, 0.45, 0.45) if c["hp"] <= 0 else Color.WHITE


func _highlight(actor):
	for c in squad:
		_restyle(c, is_same(c, actor))


func _clear_commands():
	for child in command_bar.get_children():
		child.queue_free()


# mode: "" (none), "enemy" or "ally"
func _set_targeting(mode):
	var first = null
	for c in squad + enemies:
		var enabled = c["hp"] > 0 and ((mode == "enemy" and c["is_enemy"]) or (mode == "ally" and not c["is_enemy"]))
		c["button"].disabled = not enabled
		if enabled and first == null:
			first = c["button"]
	if first != null:
		first.grab_focus()


func _log(text):
	log_box.append_text(text + "\n")


func _float(c, text, color):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	overlay.add_child(l)
	var p = c["panel"]
	c["float_n"] = (c.get("float_n", 0) + 1) % 3
	l.position = p.global_position + Vector2(p.size.x * 0.5 - 60, 6 + c["float_n"] * 26)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 50, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.finished.connect(l.queue_free)


func _flash(c):
	var p = c["panel"]
	p.modulate = Color(2.2, 2.2, 2.2)
	var tw = create_tween()
	tw.tween_property(p, "modulate", Color.WHITE, 0.25)


func _banner(title, color):
	var l = Label.new()
	l.text = title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 48)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.size = Vector2(size.x, 70)
	l.position = Vector2(0, size.y * 0.33)
	overlay.add_child(l)
	return l


func _fading_banner(title, color):
	var l = _banner(title, color)
	var tw = create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.finished.connect(l.queue_free)


# ---------------------------------------------------------------- combat math (Stats & Damage GDD)

func _hit(user, target, power):
	if target["hp"] <= 0:
		return 0
	var atk = float(maxi(1, user["atk"]))
	var def = float(maxi(0, target["def"]))
	var base = (float(power) / POWER_SCALE) * atk * atk / (atk + def)        # F3
	var pct = 0.0
	var notes = PackedStringArray()
	if target["states"].has("Defending"):
		pct += DEFEND_PCT
		notes.append("defending")
	if target["states"].has("Gone Viral"):
		pct += VIRAL_PCT
		notes.append("gone viral")
	var modified = maxf(0.0, base) * clampf(1.0 + pct, MULT_MIN, MULT_MAX)  # F5
	var varied = modified * rng.randf_range(1.0 - VARIANCE, 1.0 + VARIANCE) # F6
	var amount = clampi(int(floor(varied + 0.5)), 1, DAMAGE_CAP)            # F7
	target["hp"] = clampi(target["hp"] - amount, 0, target["max_hp"])
	_float(target, str(amount), C_TEXT)
	var note = "" if notes.is_empty() else " (" + ", ".join(notes) + ")"
	_log("   %s takes %d damage%s." % [target["name"], amount, note])
	if target["hp"] <= 0:
		target["states"].clear()
		_log("   [b]%s is knocked out![/b]" % target["name"])
	else:
		_flash(target)
	_refresh(target)
	return amount


func _heal_amount(user, power):
	return int(floor(power * (1.0 + float(user["atk"]) / HEAL_ATTACK_SCALE) + 0.5))  # F4


func _heal(target, amount):
	if target["hp"] <= 0:
		return 0
	var before = target["hp"]
	target["hp"] = clampi(target["hp"] + amount, 0, target["max_hp"])
	_float(target, "+%d" % amount, C_HEAL)
	_refresh(target)
	return target["hp"] - before


# ---------------------------------------------------------------- turn flow

func _living(arr):
	var out = []
	for c in arr:
		if c["hp"] > 0:
			out.append(c)
	return out


func _find_move(a, move_name):
	for m in a["moves"]:
		if m["name"] == move_name:
			return m
	return {}


func _block_reason(a, m):
	if _is_suspended(a) and m["name"] != "Attack":
		return "SUSPENDED"
	if m["special"] and not _specials_allowed():
		return "PERMIT PENDING"
	if a["mp"] < m["cost"]:
		return "NOT ENOUGH MP"
	return ""


func _start_actor_turn():
	if battle_over:
		return
	while actor_idx < squad.size() and squad[actor_idx]["hp"] <= 0:
		actor_idx += 1
	if actor_idx >= squad.size():
		_enemy_phase()
		return
	var a = squad[actor_idx]
	if a["states"].has("Defending"):
		a["states"].erase("Defending")
		_refresh(a)
	_highlight(a)
	pending_move = {}
	_set_targeting("")
	var suspended = _is_suspended(a)
	if suspended:
		suspended_turns += 1
	prompt_label.text = "Round %d — %s's turn. %s" % [round_no, a["name"],
		"SUSPENDED (0 MP): basic Attack only." if suspended else "Choose a command."]
	_clear_commands()
	var first = null
	for m in a["moves"]:
		var b = Button.new()
		var label = m["name"]
		if m["cost"] > 0:
			label += "   (%d MP)" % m["cost"]
		var reason = _block_reason(a, m)
		if reason == "PERMIT PENDING":
			b.tooltip_text = "Banned until the government permit arrives (round %d).\n%s" % [PERMIT_ROUNDS + 1, m["desc"]]
		elif reason == "SUSPENDED":
			b.tooltip_text = "Your MegaCorp account is suspended (0 MP). Basic Attack only.\n%s" % m["desc"]
		else:
			b.tooltip_text = m["desc"]
		if reason == "PERMIT PENDING" or reason == "SUSPENDED":
			label += "   [%s]" % reason
		b.text = label
		b.custom_minimum_size = Vector2(0, 48)
		b.disabled = reason != ""
		b.pressed.connect(_on_move.bind(m))
		command_bar.add_child(b)
		if first == null and not b.disabled:
			first = b
	if first != null:
		first.grab_focus()
	if autoplay:
		call_deferred("_auto_act")


func _on_move(m):
	if busy or battle_over:
		return
	if m["target"] == "enemy" or m["target"] == "ally":
		pending_move = m
		var where = "an enemy on the right" if m["target"] == "enemy" else "an ally on the left"
		prompt_label.text = "%s — %s. Now choose %s." % [squad[actor_idx]["name"], m["name"], where]
		_set_targeting(m["target"])
	else:
		_execute(m, {})


func _on_target(is_enemy_side, i):
	if busy or battle_over or pending_move.is_empty():
		return
	var m = pending_move
	pending_move = {}
	_execute(m, enemies[i] if is_enemy_side else squad[i])


func _execute(m, target):
	var user = squad[actor_idx]
	_set_targeting("")
	busy = true

	user["mp"] -= m["cost"]
	if m["cost"] > 0:
		_float(user, "-%d MP" % m["cost"], C_MP)
	if m["special"]:
		specials_used += 1
	if faction == "bureaucratia" and not _specials_allowed():
		if m["kind"] == "defend":
			defends_pending += 1
		elif m["kind"] == "damage":
			attacks_pending += 1

	match m["kind"]:
		"damage":
			_log("%s uses [b]%s[/b] on %s." % [user["name"], m["name"], target["name"]])
			_hit(user, target, m["power"])
		"defend":
			user["states"]["Defending"] = 1
			_log("%s hunkers down (Defending)." % user["name"])
			_float(user, "DEFEND", C_MP)
		"stun":
			_log("%s uses [b]%s[/b] on %s." % [user["name"], m["name"], target["name"]])
			if target["is_boss"]:
				boss_complaints += 1
				_float(target, "NO EFFECT", _faction_color())
				if faction == "bureaucratia":
					_log("   The %s [i]is[/i] the manager. The complaint gets forwarded to himself." % target["name"])
				else:
					_log("   The %s outsourced customer service years ago. The complaint goes to a chatbot." % target["name"])
			else:
				target["states"]["Stunned"] = 1
				stuns_landed += 1
				_float(target, "STUNNED", C_QUIRK)
				_log("   %s is speechless and loses its next turn." % target["name"])
		"heal":
			var got = _heal(target, _heal_amount(user, m["power"]))
			healed_total += got
			_log("%s serves %s an [b]%s[/b]: +%d HP." % [user["name"], target["name"], m["name"], got])
		"regen":
			var amt = _heal_amount(user, m["power"])
			_log("%s serves a [b]%s[/b] to the squad." % [user["name"], m["name"]])
			for ally in _living(squad):
				ally["states"]["Regen"] = m["turns"]
				ally["regen_amt"] = amt
				_float(ally, "REGEN", C_HEAL)
				_refresh(ally)
			_log("   Everyone recovers %d HP at the end of each round for %d rounds." % [amt, m["turns"]])
		"viral":
			_log("%s uses [b]%s[/b] on %s." % [user["name"], m["name"], target["name"]])
			target["states"]["Gone Viral"] = m["turns"]
			_float(target, "GONE VIRAL", C_QUIRK)
			_log("   %s is all over the internet and takes 50%% more damage." % target["name"])

	_refresh(user)
	if not target.is_empty():
		_refresh(target)

	await get_tree().create_timer(0.6).timeout
	busy = false
	if _check_end():
		return
	actor_idx += 1
	_start_actor_turn()


func _enemy_phase():
	_highlight(null)
	_clear_commands()
	_set_targeting("")
	prompt_label.text = "Round %d — %s's turn." % [round_no, "Bureaucratia" if faction == "bureaucratia" else "MegaCorp"]
	busy = true
	for e in enemies:
		if battle_over:
			break
		if e["hp"] <= 0:
			continue
		e["states"].erase("Defending")
		if e["states"].has("Stunned"):
			e["states"].erase("Stunned")
			_log("%s is still speechless and does nothing." % e["name"])
			_refresh(e)
			await get_tree().create_timer(0.5).timeout
			continue
		var targets = _living(squad)
		if targets.is_empty():
			break
		if faction == "bureaucratia":
			_bureaucratia_act(e, targets)
		else:
			_megacorp_act(e, targets)
		_refresh(e)
		await get_tree().create_timer(0.7).timeout
		if _check_end():
			busy = false
			return
	_end_round()
	busy = false


func _weakest(targets):
	var w = targets[0]
	for t in targets:
		if _hp_pct(t) < _hp_pct(w):
			w = t
	return w


func _bureaucratia_act(e, targets):
	var weakest = _weakest(targets)
	if not _specials_allowed():
		if _hp_pct(weakest) > LOW_HP:
			# Nobody is hurt yet: hunker down and only jab.
			e["states"]["Defending"] = 1
			var jab_target = targets[rng.randi_range(0, targets.size() - 1)]
			_log("%s hunkers down behind a stack of forms and jabs %s with a pen." % [e["name"], jab_target["name"]])
			_hit(e, jab_target, 5)
			return
		_log("%s smells weakness and goes for %s!" % [e["name"], weakest["name"]])
		_hit(e, weakest, 10)
		return
	# Permit granted: all-out war.
	if e["is_boss"]:
		if round_no % 2 == 0:
			_log("%s orders a [b]Mass Audit[/b] on the whole squad!" % e["name"])
			for t in targets:
				_hit(e, t, 8)
		else:
			_log("%s issues a [b]Final Notice[/b] to %s!" % [e["name"], weakest["name"]])
			_hit(e, weakest, 18)
	else:
		_log("%s slaps %s with a [b]Late Fee[/b]!" % [e["name"], weakest["name"]])
		_hit(e, weakest, 16)


func _megacorp_act(e, targets):
	var weakest = _weakest(targets)
	if e["is_boss"]:
		if round_no % 2 == 1:
			_log("%s announces [b]Layoffs[/b]! Everyone takes a hit." % e["name"])
			for t in targets:
				_hit(e, t, 8)
		else:
			_log("%s attempts a [b]Hostile Takeover[/b] of %s!" % [e["name"], weakest["name"]])
			_hit(e, weakest, 18)
	elif e["name"] == "Middle Manager":
		# Upsell: drain MP from whoever has the most, pushing them toward suspension.
		var richest = targets[0]
		for t in targets:
			if t["mp"] > richest["mp"]:
				richest = t
		var drained = mini(3, richest["mp"])
		richest["mp"] -= drained
		mp_billed += drained
		_log("%s [b]upsells[/b] %s to the premium tier (-%d MP)." % [e["name"], richest["name"], drained])
		if drained > 0:
			_float(richest, "-%d MP UPSOLD" % drained, C_CYAN)
		_hit(e, richest, 6)
		_refresh(richest)
	else:
		_log("%s runs a [b]Laser Scan[/b] and locks onto %s." % [e["name"], weakest["name"]])
		_hit(e, weakest, 11)


func _end_round():
	var regen_lines = PackedStringArray()
	for c in squad + enemies:
		if c["hp"] <= 0:
			continue
		if c["states"].has("Regen"):
			var got = _heal(c, c["regen_amt"])
			healed_total += got
			regen_lines.append("%s +%d" % [c["name"], got])
		var expired = []
		for s in c["states"]:
			if s in ["Gone Viral", "Regen"]:
				c["states"][s] -= 1
				if c["states"][s] <= 0:
					expired.append(s)
		for s in expired:
			c["states"].erase(s)
			_log("   %s's [i]%s[/i] wore off." % [c["name"], s])
		_refresh(c)
	if regen_lines.size() > 0:
		_log("   Regen: " + ", ".join(regen_lines))

	if faction == "megacorp":
		var billed = PackedStringArray()
		for c in _living(squad):
			var was_active = c["mp"] > 0
			var amt = mini(BILL_MP, c["mp"])
			if amt > 0:
				c["mp"] -= amt
				mp_billed += amt
				_float(c, "-%d MP BILLED" % amt, C_CYAN)
				billed.append("%s -%d" % [c["name"], amt])
			if was_active and c["mp"] <= 0:
				_log("   [color=#19C2D6]%s's account is SUSPENDED (0 MP): basic Attack only.[/color]" % c["name"])
			_refresh(c)
		if billed.size() > 0:
			_log("   [color=#19C2D6]Subscription renewed:[/color] " + ", ".join(billed))

	if faction == "bureaucratia" and round_no == PERMIT_ROUNDS:
		var hp = 0
		var max_hp = 0
		for c in squad:
			hp += c["hp"]
			max_hp += c["max_hp"]
		hp_pct_at_permit = int(round(100.0 * hp / max_hp))
		_log("[color=#f2c14e][b]The government permit arrives. ALL-OUT WAR — special moves are allowed for both sides![/b][/color]")
		_fading_banner("PERMIT GRANTED — ALL-OUT WAR!", C_QUIRK)

	round_no += 1
	_update_rule_banner()
	actor_idx = 0
	_log("[b]— Round %d —[/b]" % round_no)
	_start_actor_turn()


func _check_end():
	if _living(enemies).is_empty():
		_finish(true)
		return true
	if _living(squad).is_empty():
		_finish(false)
		return true
	return false


func _finish(won):
	battle_over = true
	_clear_commands()
	_set_targeting("")
	_highlight(null)
	var title = ("PLANET LIBERATED!" if won else "SQUAD DEFEATED")
	prompt_label.text = title + "   —   press R to pick a planet again."
	var summary = "faction: %s | result: %s | rounds: %d | specials used: %d | stuns landed: %d | complaints wasted on boss: %d | HP healed: %d" % [
		faction, "win" if won else "loss", round_no, specials_used, stuns_landed, boss_complaints, healed_total]
	if faction == "bureaucratia":
		var permit_txt = ("%d%%" % hp_pct_at_permit) if hp_pct_at_permit >= 0 else "n/a"
		summary += " | attacks during permit wait: %d | defends during permit wait: %d | squad HP when permit arrived: %s" % [
			attacks_pending, defends_pending, permit_txt]
	else:
		summary += " | MP billed/upsold: %d | turns spent suspended: %d" % [mp_billed, suspended_turns]
	_log("")
	_log("[b]%s[/b]" % title)
	_log("[i]Playtest data — %s[/i]" % summary)
	print("PROTOTYPE RESULT: ", summary)
	_banner(title, C_HEAL if won else _faction_color())
	if autoplay:
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()


# ---------------------------------------------------------------- dev-only autoplay

func _auto_act():
	if busy or battle_over:
		return
	var a = squad[actor_idx]
	var live = []
	for i in enemies.size():
		if enemies[i]["hp"] > 0:
			live.append(i)
	var tgt = live[0]
	for i in live:
		if enemies[i]["hp"] < enemies[tgt]["hp"]:
			tgt = i
	var attack = _find_move(a, "Attack")

	if OS.get_cmdline_user_args().has("--naive") or _is_suspended(a):
		_on_move(attack)
		_on_target(true, tgt)
		return

	if not _specials_allowed():
		if _hp_pct(a) <= LOW_HP:
			_on_move(_find_move(a, "Defend"))
			return
		_on_move(attack)
		_on_target(true, tgt)
		return

	match a["name"]:
		"Karen":
			var m = _find_move(a, "Speak to the Manager")
			if _block_reason(a, m) == "":
				for i in live:
					if not enemies[i]["is_boss"] and not enemies[i]["states"].has("Stunned"):
						_on_move(m)
						_on_target(true, i)
						return
		"Michelin Chef":
			var app = _find_move(a, "Appetizer")
			var meal = _find_move(a, "Family Meal")
			var low_i = -1
			for i in squad.size():
				if squad[i]["hp"] > 0 and _hp_pct(squad[i]) < 0.5:
					if low_i < 0 or _hp_pct(squad[i]) < _hp_pct(squad[low_i]):
						low_i = i
			if low_i >= 0 and _block_reason(a, app) == "":
				_on_move(app)
				_on_target(false, low_i)
				return
			if _block_reason(a, meal) == "":
				for ally in _living(squad):
					if _hp_pct(ally) < 0.7 and not ally["states"].has("Regen"):
						_on_move(meal)
						return
		"Florida Man":
			var m = _find_move(a, "Viral Stunt")
			if _block_reason(a, m) == "":
				for i in live:
					if enemies[i]["is_boss"] and not enemies[i]["states"].has("Gone Viral"):
						_on_move(m)
						_on_target(true, i)
						return
		"Baguette Thrower":
			var m = _find_move(a, "Baguette Home Run")
			if _block_reason(a, m) == "":
				var pick = tgt
				for i in live:
					if enemies[i]["states"].has("Gone Viral"):
						pick = i
				_on_move(m)
				_on_target(true, pick)
				return
	_on_move(attack)
	_on_target(true, tgt)
