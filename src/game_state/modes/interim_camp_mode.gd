## Interim Camp mode (GDD `game-state-scene-flow.md` modes; Overworld rules
## 13 and 13a; story 089). Entered by resting at a CampSpot or by Retreat
## after a Defeat; shows a rest card, and `confirm` sets out again: a fade
## to the camp's map at its CampSpot's return EntryPoint
## (`CampDirectory.return_payload()`, the region default camp when no camp
## is registered). The Camp & Party Management system (not designed)
## replaces it: party management, healing and the rest gags belong there.
class_name InterimCampMode extends GameMode

## Injected by `GameRoot` before `setup()`.
var camp_directory: CampDirectory = null
## Injected by `GameRoot`: setting out autosaves to slot 1 (provisional, the
## Save/Load GDD owns when saves happen; ADR-0009 §4).
var save_service: SaveService = null
## The last autosave result (tests).
var last_save_result: int = -1
var _machine: GameStateMachine = null
## The party resting here (`GameRoot` injects the one squad the Overworld
## shares): resting restores every member to full HP and MP, knocked-out
## members included (Stats & Damage rule 3: characters carry HP/MP between
## battles and are restored to full at camp). Null rests nobody.
var party_source: Callable = Callable()
## The camp being rested at (the payload's ID; may be empty on a Retreat
## with no camp registered).
var camp_id: String = ""
## Injected by `GameRoot`: the wallet and bag the shop reads and writes
## (Items & Shops rule 9). Null = no shop.
var world_state: WorldState = null
## Injected by `GameRoot`: the `item_` record source. Null = no shop.
var item_catalog: Object = null
## What this camp sells; the shipped config when not injected.
var shop_config: ShopConfig = null

enum Screen { MAIN, SHOP }
## Main-screen entries, in order. Set out is first and selected, so one
## confirm still sets out (the rest card's original behaviour).
const SET_OUT: String = "Set out"
const SHOP: String = "Shop"
const DONE: String = "Done"
var screen: Screen = Screen.MAIN
## The highlighted row of the current screen.
var cursor: int = 0
## The last purchase's result line ("" before any).
var shop_message: String = ""
var _stock: Array[ItemData] = []


func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	var camp: CampEntryPayload = payload as CampEntryPayload
	camp_id = camp.camp_id if camp != null else ""
	restore_party()
	_load_stock()
	_render()


## The current screen's rows: Set out (and Shop when this camp sells
## anything), or one row per item on the shelf plus Done.
func rows() -> Array[String]:
	var out: Array[String] = []
	if screen == Screen.MAIN:
		out.append(SET_OUT)
		if not _stock.is_empty():
			out.append(SHOP)
		return out
	for rec: ItemData in _stock:
		out.append(rec.id)
	out.append(DONE)
	return out


## The shelf (tests).
func get_stock() -> Array[ItemData]:
	return _stock.duplicate()


func _load_stock() -> void:
	_stock.clear()
	if world_state == null or item_catalog == null:
		return
	var cfg: ShopConfig = shop_config if shop_config != null else ShopConfig.load_default()
	for id: String in cfg.stock_for(camp_id):
		var rec: ItemData = item_catalog.call(&"get_record", &"item", id) as ItemData
		if rec != null:
			_stock.append(rec)


func _render() -> void:
	var card: Label = get_node_or_null(^"%Card") as Label
	if card == null:
		return
	var lines: PackedStringArray = []
	var r: Array[String] = rows()
	if screen == Screen.MAIN:
		lines.append("Resting at camp. Everyone is back on their feet.")
		if world_state != null:
			lines.append("Money: %d" % world_state.money)
		lines.append("")
		for i: int in r.size():
			lines.append(("> %s <" if i == cursor else "%s") % r[i])
	else:
		lines.append("Café counter -- Money: %d" % world_state.money)
		lines.append("")
		for i: int in r.size():
			var text: String = DONE
			if i < _stock.size():
				var rec: ItemData = _stock[i]
				var gear: String = Equipment.bonus_text(rec)
				text = "%s%s  %d  (have %d)" % [rec.display_name, "" if gear.is_empty() else " [%s]" % gear,
						rec.price, world_state.inventory.count(rec.id)]
			lines.append(("> %s <" if i == cursor else "%s") % text)
		lines.append("")
		lines.append(_stock[cursor].description if cursor < _stock.size() else "Back to the café table.")
		if not shop_message.is_empty():
			lines.append(shop_message)
	card.text = "\n".join(lines)
	# The shelf is long: a smaller size keeps every row on screen at 720p.
	card.add_theme_font_size_override(&"font_size", 20 if screen == Screen.SHOP else 30)


## Restores every party member to full HP and MP and clears battle-only
## state (Stats & Damage rule 3). Called on arriving at camp, a Retreat
## included.
func restore_party() -> void:
	if not party_source.is_valid():
		return
	for member: Combatant in party_source.call():
		member.reset_for_battle()


## Up/down move the highlight, `confirm` picks the row (Set out, Shop, buy
## one of an item, Done), `cancel` leaves the shop. Every action is consumed.
func handle_action(action: StringName, pressed: bool) -> bool:
	if not pressed:
		return true
	var count: int = rows().size()
	if action == InputActions.NAV_UP or action == InputActions.MOVE_UP:
		cursor = (cursor - 1 + count) % count
	elif action == InputActions.NAV_DOWN or action == InputActions.MOVE_DOWN:
		cursor = (cursor + 1) % count
	elif action == InputActions.CANCEL and screen == Screen.SHOP:
		_open(Screen.MAIN)
	elif action == InputActions.CONFIRM:
		_pick(rows()[cursor])
	_render()
	return true


func _pick(row: String) -> void:
	if row == SET_OUT:
		set_out()
	elif row == SHOP:
		_open(Screen.SHOP)
	elif row == DONE:
		_open(Screen.MAIN)
	else:
		var rec: ItemData = _stock[cursor]
		var result: Shop.Result = Shop.buy(world_state, rec)
		shop_message = "Bought: %s." % rec.display_name if result == Shop.Result.OK \
				else "%s: %s." % [rec.display_name, Shop.reason(result)]


func _open(next: Screen) -> void:
	screen = next
	cursor = 0 if next == Screen.SHOP else rows().find(SHOP)
	cursor = maxi(cursor, 0)
	shop_message = ""


## Requests the Overworld at the camp's return EntryPoint. Returns Game
## State's result, or `REJECTED_INVALID_PAYLOAD` with an error logged when
## no camp return is known.
func set_out() -> GameStateMachine.RequestResult:
	var target: MapEntryPayload = camp_directory.return_payload(camp_id) if camp_directory != null else null
	if target == null or _machine == null:
		push_error("InterimCampMode: no return for camp '%s'" % camp_id)
		return GameStateMachine.RequestResult.REJECTED_INVALID_PAYLOAD
	if save_service != null:
		last_save_result = save_service.save_to_slot(1)
	return _machine.request_transition(GameStateMachine.Mode.OVERWORLD, target)
