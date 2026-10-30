class_name CaptureIdTags
extends RefCounted
## Per-cue capture-ID tags for the presentation capture tool (ADR-0005 §14,
## amending the §13 tool; ADR-0012 Ordering Note; Overworld GDD "Tooling
## owed"; story overworld 134, test plan OW-T02). A cue node carries its tag
## as node metadata `capture_id`; the capture tool's ID pass paints every
## `GeometryInstance3D` under a tagged node in that tag's flat colour, so the
## tag resolves to a stable mask (AC-44a/b, AC-32, AC-45e, AC-54).
##
## The tag strings are the ADR's: `beacon` covers every waypoint beacon in a
## leg's chain, the exit beacon included (the story's `exit_beacon` is that
## tag; ADR-0005 §14 has no separate one). `SKY` is the sky card's tag, set by
## the presentation layer (`sky`, normalised by the tool), not here.
##
## Pure and static: it only writes and reads node metadata.

## Node metadata key (the same as `PresentationCapture.META_CAPTURE_ID`).
const META: StringName = &"capture_id"

const SKY: String = "SKY"
const NOTICE_SLIP: String = "notice_slip"
const CHASE_TAG: String = "chase_tag"
const STUN_POSE: String = "stun_pose"
const CHECKPOINT_OPEN: String = "checkpoint_open"
const CHECKPOINT_CLOSED: String = "checkpoint_closed"
const SAFE_PAVING: String = "safe_paving"
const BEACON: String = "beacon"
const CAMP_SIGN: String = "camp_sign"
const INTERACT_PROMPT: String = "interact_prompt"
const SYMBOL: String = "symbol"

## Every §14 tag, in the capture tool's palette order.
const ALL: Array[String] = [SKY, NOTICE_SLIP, CHASE_TAG, STUN_POSE, CHECKPOINT_OPEN,
		CHECKPOINT_CLOSED, SAFE_PAVING, BEACON, CAMP_SIGN, INTERACT_PROMPT, SYMBOL]


## Sets `node`'s capture-ID to `tag` (one of `ALL`). An unknown tag is an
## error and leaves the node untouched.
static func tag(node: Node, cue_tag: String) -> void:
	if node == null:
		return
	if not ALL.has(cue_tag):
		push_error("CaptureIdTags: unknown capture-ID tag '%s'" % cue_tag)
		return
	node.set_meta(META, cue_tag)


## `node`'s own capture-ID, or "" when it has none.
static func tag_of(node: Node) -> String:
	if node == null or not node.has_meta(META):
		return ""
	return String(node.get_meta(META))


## The checkpoint cue's tag for its state.
static func checkpoint_tag(is_open: bool) -> String:
	return CHECKPOINT_OPEN if is_open else CHECKPOINT_CLOSED


## The symbol sprite's tag for its brain sub-state: the notice slip while
## Noticing, the chase tag while Chasing, the stun pose while Stunned, else
## `symbol`. TODO(sprite-camera-presentation): when the slip and the tag are
## drawn as their own nodes, tag those nodes and keep the sprite `symbol`.
static func symbol_tag(sub_state: SymbolBrain.SubState) -> String:
	match sub_state:
		SymbolBrain.SubState.NOTICING:
			return NOTICE_SLIP
		SymbolBrain.SubState.CHASING:
			return CHASE_TAG
		SymbolBrain.SubState.STUNNED:
			return STUN_POSE
	return SYMBOL


## Tags `map`'s cue markers and the placeholder set `build_set()` drew:
## waypoint beacons and exit patches `beacon`, camp spots and their patches
## `camp_sign`, checkpoint barriers `checkpoint_closed`, and each checkpoint
## marker by `is_open.call(marker_id) -> bool`.
static func tag_map(map: OverworldMap, is_open: Callable) -> void:
	if map == null:
		return
	for b: Node in map.find_children("*", "Marker3D", true, false):
		if b is WaypointBeacon:
			tag(b, BEACON)
	for camp: CampSpot in map.camp_spots():
		tag(camp, CAMP_SIGN)
	for cp: CheckpointMarker in map.checkpoints():
		tag(cp, checkpoint_tag(bool(is_open.call(cp.marker_id))))
	var set_root: Node = map.get_node_or_null(^"PlaceholderSet")
	if set_root == null:
		return
	for n: Node in set_root.get_children():
		var node_name: String = String(n.name)
		if node_name.begins_with("ExitPatch_"):
			tag(n, BEACON)
		elif node_name.begins_with("CampPatch_"):
			tag(n, CAMP_SIGN)
		elif node_name.begins_with("Checkpoint_"):
			tag(n, CHECKPOINT_CLOSED)
