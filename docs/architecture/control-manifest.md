# Control Manifest

> **Engine**: Godot 4.7.2 (GDScript)
> **Last Updated**: 2026-10-23
> **Manifest Version**: 2026-10-23
> **ADRs Covered**: ADR-0001 to ADR-0013 (all 13; ADR-0002 including its §11 revision of 2026-10-23)
> **ADRs Left Out**: None
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Stories embed it when
they are written, and `/story-readiness` compares a story's version with this one
to find stories written against old rules. It always equals `Last Updated`: the
same date, for different readers.

This manifest is a programmer's quick reference taken from the Accepted ADRs, the
technical preferences and the engine reference docs. For the reason behind a rule,
read its ADR.

**Coverage today:** all 13 ADRs are Accepted, and every layer has rules below:
- Foundation: Content Data Definitions, Content Boot Ordering, Game State & Scene Flow, Input System.
- Core: Sprite & Camera Presentation, Stats & Damage Resolution, Save/Load & Settings.
- Feature: Battle Replay Ownership, Turn Battle System, Faction Rule Modifiers, Overworld Exploration & Encounters.
- Presentation: UI Framework, Localization.


**Regenerated 2026-10-23.** Adds ADR-0012 (Accepted 2026-10-23), the ADR-0002 §11 revision (in-mode fade, `register_camp`), ADR-0012's amendments to ADR-0001 and ADR-0005, the `performance.per_system.overworld_ms` budget and the `Engine.time_scale` ban. Stories stamped 2026-10-22 that touch Game State transitions, camps or presentation profiles should be re-checked against these rules.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine start-up, the
Content Data Definitions catalog (`ContentCatalog`), the Game State & Scene Flow
machine, and the Input System*

### Required Patterns

**Content Data Definitions (ADR-0001)**

*Record types and files*
- **Every content record type is its own `Resource` subclass** (`class_name`, `extends Resource`) with every scalar and enum field as a typed `@export` var — source: ADR-0001
- **EffectDescriptors (`effects` fields) are stored as plain `Array[Dictionary]`** (`{type, ...params}`), the one non-scalar export — source: ADR-0001 (GDD Requirements, Rule 4 row)
- **Every record exports `id: String`**, and `aliases: PackedStringArray` where ID aliasing applies — source: ADR-0001
- **One record = one `.tres` file at `data/[type_plural]/[id].tres`** (e.g. `data/characters/char_baguette_thrower.tres`); the filename without extension must equal the record's `id`, and the validation pass checks it — source: ADR-0001
- **Cross-references are `String` / `PackedStringArray` fields holding record IDs** (`nation_id`, `move_ids`, `faction_id`, …) — source: ADR-0001
- **Record scripts live at a stable path (`src/data/records/`) and are not renamed casually**: every `.tres` references its script by path — source: ADR-0001

*Loading and access*
- **`ContentCatalog` is an autoload singleton**, registered under `[autoload]` in `project.godot`. The one documented exception to "dependency injection over singletons" — source: ADR-0001
- **Discover files with `ResourceLoader.list_directory(path)`**, recursed per subdirectory under `data/` — source: ADR-0001
- **Lookup API names are `get_record(type, id)`, `has_record(type, id)`, `all_records(type)` (sorted by `id`) and `resolve_alias(id)`**; state is `ContentCatalog.state` (`UNLOADED | LOADING | VALIDATING | READY | FAILED`) — source: ADR-0001
- **The catalog loads once per session; `READY` is terminal.** A second `load_all()` is rejected — source: ADR-0001
- **Consumers copy a record's values into their own runtime objects** (`Combatant`, `Move`) at construction time; records are shared, cached `Resource` instances — source: ADR-0001
- **Static factories become adapters**: they read the catalog record and build today's runtime `Move` / `Combatant` objects. `BattleCore` never touches a catalog record — source: ADR-0001
- **Attack and Defend stay code-side factories** (`Move.make_attack()` / `make_defend()`), not records — source: ADR-0001

*Validation*
- **Validation runs over the complete record set before reporting**, every problem collected — source: ADR-0001
- **The validation pass covers**: ID format and uniqueness, filename = `id`, reference resolution, cycle detection, numeric ranges, unknown fields, parse failures and Resource-typed exports — source: ADR-0001
- **Each error class has a deliberately malformed `.tres` fixture** that must produce its named validation error, not a crash or silent skip — source: ADR-0001
- **Unknown fields are detected by reading each `.tres` file's raw text (`FileAccess`)**, parsing the `[resource]` section's `key = value` lines, and diffing against the instance's `get_property_list()` — source: ADR-0001
- **Every required field has an enforced validity rule** (non-empty text, numeric range from the owning GDD) — source: ADR-0001
- **Check `ResourceLoader.load(path)` for `null`**, record a validation error naming the file, and keep loading the rest — source: ADR-0001
- **Validation rejects any record script that declares an Object/Resource-typed export** — source: ADR-0001
- **Owning systems register their vocabulary before validation**: Turn Battle System calls `ContentCatalog.register_known_effect_types(system, types)`. `Faction.rule_id` is an ordinary reference to a `faction_rule` record, checked by the generic reference pass, and the record's `rule_class` resolves through `FactionRuleRegistry`, never by reflection — source: ADR-0001, as amended by ADR-0011 §4–§5
- **Numeric ranges (e.g. `max_hp` 1–999) are owned by Stats & Damage Resolution** and checked by its validators (`StatsValidators.*`, with `StatsConfig` bound), registered through `ContentBootstrap`. They are never written as literals in `ContentCatalog` — source: ADR-0001, as amended by ADR-0007 §7
- **Every string-typed record export is listed in exactly one of the record script's `LOC_FIELDS` or `NON_LOC_FIELDS`**. `LocFieldsValidator` is registered for every record type and checks it at boot, and that every `LOC_FIELDS` value has balanced `{placeholder}` braces — source: ADR-0013 §4 (ADR-0004 amendment)
- **Headless validation script at `res://tools/ci/validate-content.gd`**, exiting with `min(error_count, 1)` and accepting `--data-root=` — source: ADR-0001 (amendment 2026-10-23)

*Migration*
- **Characterization tests are written against today's hardcoded factories before migration** and rerun unchanged after it — source: ADR-0001
- **Run each verification or characterization pass in a fresh engine process**: `ResourceLoader.load()` defaults to `CACHE_MODE_REUSE` — source: ADR-0001
- **Enemy AI keys behaviour off the record `id`, never `display_name`** — source: ADR-0001
- **The five migrated EffectDescriptor types are `stun`, `heal_party`, `heal_single`, `damage_debuff`, `direct_damage`**, provisional until Quirk State System is designed — source: ADR-0001

**Content Boot Ordering (ADR-0004)**
- **`ContentBootstrap.run(catalog)` is the one place that knows every registrant**, and runs, in order:
  1. Turn Battle registration.
  2. Faction Rule registration: builds the `FactionRuleRegistry` (`FactionRules.register_all()`) and registers its rule-record validators.
  3. Every `register_record_validator` call: `InputBindingsValidator`, the Stats validators (`StatsConfig.load_or_default()` bound), and `LocFieldsValidator` for every record type.
  4. `catalog.load_all()`.

  It returns its boot result (`PresentationConfig`, the `FactionRuleRegistry`) to `GameRoot`. It is a no-op unless `catalog.state == UNLOADED` — source: ADR-0004, as amended by ADR-0007 §7, ADR-0011 and ADR-0013
- **`GameRoot._enter_tree()` calls only `ContentBootstrap.run()`.** Everything else is built in `GameRoot._ready()`, by which point the load has already finished. That includes `SettingsService` (created first), `TransitionConfig`, `InputConfig`, `InputResolver`, `GameStateMachine`, `FlashGate`, `PresentationDirector`, `UiService` and `SaveService` — source: ADR-0004, ADR-0008 §1, ADR-0009 §7
- **`ContentCatalog` sets up all its state in field initializers or `_init()`.** Its `_ready()` must do nothing to catalog state — it runs *after* the bootstrap has loaded (verified on 4.7.2: an autoload's `_ready()` runs after the main scene's `_enter_tree()`) — source: ADR-0004
- **`register_record_validator(type, validator)`** — `validator: func(record) -> Array[Dictionary]` returns structured entries (`severity`, `field`, `message`, optional `related_locations`) and must be pure (empty array = valid; amended 2026-10-23); a registration made after `load_all()` has started is rejected — source: ADR-0004
- **Harness scenes and `validate-content.gd` call `ContentBootstrap.run()`** in their own `_enter_tree()` / `_initialize()`, never `_init()` — source: ADR-0004
- **The catalog script declares `class_name ContentCatalogService`**, distinct from its autoload node name `ContentCatalog` — source: ADR-0004
- **Nodes under `GameRoot` get catalog data through `setup()`**, not by reading the catalog in their own `_ready()` — source: ADR-0004
- **An ADR that adds a registrant must name its line in `ContentBootstrap.run()`** — source: ADR-0004

**Game State & Scene Flow (ADR-0002)**
- **Split into a pure logic core (`GameStateMachine`, `RefCounted`) and a thin scene-tree shell (`GameRoot`)**, joined by injected interfaces — source: ADR-0002
- **`GameStateMachine` must never reference the scene tree, `get_tree()`, an autoload by name, `Time`, or `Engine`.** Time enters only through `tick(delta)`; every collaborator enters only through `_init` — source: ADR-0002
- **Game State must never be an autoload.** Delivered to every consumer through `setup()` — source: ADR-0002
- **Mode swap = child swap under `ModeHost`.** `SceneTree.change_scene_to_*` is never used — source: ADR-0002
- **Overworld freeze = detach (`remove_child`), never serialize.** `on_freezing()` runs first; the instance stays alive, unparented — source: ADR-0002
- **Menu stops time by disabling `ModeHost.process_mode = PROCESS_MODE_DISABLED`.** `SceneTree.paused` is never used for this — source: ADR-0002
- **Signals fire in exactly this order for a transition**: `transition_started` (start of OUT) → `mode_exited` (start of SWAP) → `mode_entered` (end of SWAP) → `transition_finished` (end of IN). Input unlocks after `transition_finished` — source: ADR-0002
- **A transition request while `phase != IDLE` returns `REJECTED_BUSY` and changes no state**, except `request_quit()` — source: ADR-0002
- **A swap failure calls `rollback_swap()`**, re-attaches any detached Overworld, replays IN into the source mode, unlocks input and logs an error — source: ADR-0002
- **A detached Overworld is freed explicitly** on Retreat, on Quit to Title and in `GameRoot._exit_tree()`. Tests must assert no orphan nodes (gdUnit4 exit 101 is a failure for this system) — source: ADR-0002
- **Mode scripts tolerate `_exit_tree()`/`_enter_tree()` without `_ready()` running again**: one-time setup goes in `_ready()`, anything tied to tree membership in `_enter_tree()`/`_exit_tree()` — source: ADR-0002
- **Every `GameMode`/`GameOverlay` override with a typed return ends in an explicit `return`** (Godot 4.7 typed-return inheritance) — source: ADR-0002
- **A mode reads movement only through `machine.get_move_vector(self)`; discrete actions arrive only through `handle_action()`.** Modes and overlays never reference the Input System directly — source: ADR-0002
- **`TransitionPresenter` calls are fire-and-forget**; phase timing comes only from `tick()` — source: ADR-0002
- **Under Game State the Battle mode must call `BattleCore.start_battle(false)`**, never `retry_battle()` — source: ADR-0002
- **Mode/overlay scene paths, transition timings and budgets come from `TransitionConfig` data**, never literals — source: ADR-0002
- **The machine holds the `FlashGate` service, injected via `_init`.** At the start of OUT of any flashing transition it calls `flash_gate.request()`, keeps the result for the whole transition, and passes `capped` to the presenter — source: ADR-0002 (amendment, ADR-0005 §12 / ADR-0006)
- **`mode_entered(BATTLE)` still fires on a same-mode (Retry) row, but listeners must not re-apply entry state** over what `restore_start_snapshot()` already set — source: ADR-0002 (amendment, ADR-0005 §4)
- **The production `SceneLoader` and the `OverlayHost` push take an injected `pre_setup: Callable(node)`**, run after instantiation and before `setup()`. `GameRoot` binds it to `UiService` (hand a `UiContext`) and to the Battle mode's `presentation_settings`. `GameMode`/`GameOverlay` stay unchanged — source: ADR-0002, as amended by ADR-0008 §2 and ADR-0009 §7
- **The production `SceneLoader` takes an injected `payload_commit: Callable(payload) -> bool`**, called during SWAP before the target mode is instantiated. It is bound to `SaveService.commit_if_loaded()`, and `false` is a swap failure (rollback). `is_save_safe()` is unchanged — source: ADR-0002, as amended by ADR-0009 §6
- **Clearing the party's per-fight transients belongs to the Battle mode**, through `BattleCore.clear_transients(party)` before `start_battle(false)`. `ChapterFlow._clear_squad_transients()` goes away — source: ADR-0002, as amended by ADR-0010 §7

**Input System (ADR-0003)**
- **`InputResolver` (`RefCounted`) owns the binding table, held set, move vector and device state, with no scene-tree dependency.** Driven only through `feed_event()`, `tick()`, `set_window_focused()` and `on_joy_connection()` — source: ADR-0003
- **`InputSystem` node is the only script that touches engine input** (`_input`, `Input.*`, `InputMap` mutation). One named exception: `src/ui/ui_navigator.gd` (`UiNavigator`) may call `Input.parse_input_event()` for `ui_*` actions — source: ADR-0003, ADR-0008 §3
- **The binding table is the resolver's own dictionary, matched by `physical_keycode` / `JoyButton` / `JoyAxis` / `MouseButton`**, never `InputMap` — source: ADR-0003
- **Bindings are a catalog record** (`bindings_` prefix); **tuning values** (deadzone, repeat timing, `pointer_switch_px`, pad-style patterns) are a project config (`InputConfig`), not a catalog record — source: ADR-0003
- **Built-in `ui_*` navigation actions have their device bindings erased in `InputSystem._enter_tree()`**, before any `Control` can grab focus — source: ADR-0003
- **Re-injection into `ui_*` actions fires only when focus is inside the receiver's own subtree, and only as an atomic press-then-release pair.** Routed releases are never mirrored — source: ADR-0003
- **Every overlay root has a full-screen `MOUSE_FILTER_STOP` backdrop; `TransitionLayer` shows one for the whole transition** — source: ADR-0003 / ADR-0002
- **Bindings validation (`InputBindingsValidator`) registers via `ContentCatalog.register_record_validator(&"bindings", ...)`** inside `ContentBootstrap`, before `load_all()` — source: ADR-0003 / ADR-0004
- **Fallback bindings (a code constant) are used only when the catalog is `FAILED`**; never extended into a second default-bindings source — source: ADR-0003
- **`action_pressed`/`action_released` fire on edges; `action_held` fires every `tick` while held.** `nav_*` are derived actions, never bound directly — source: ADR-0003
- **`get_move_vector()` returns `Vector2.ZERO` while the window is unfocused** — source: ADR-0003
- **`project.godot` sets `input_devices/joypads/ignore_joypad_on_unfocused_application = true`** — source: ADR-0003
- **Keyboard bindings match on `physical_keycode`, never `keycode`.** Echo events are ignored — source: ADR-0003
- **`device_lost()`/`focus_lost()` fire only after every held action's `action_released`** — source: ADR-0003
- **`InputSystem` never calls `set_input_as_handled()`, and the resolver ignores `InputEventAction`** — source: ADR-0003
- **The resolver reference never leaves `GameStateMachine` and `UiService`.** Widgets (HUD prompt glyphs) reach the active device, pad style and glyphs only through `UiContext.prompts` (`PromptFacade`, which exposes no pointer data and no held state) — source: ADR-0003, ADR-0008 §4 (`GameRoot`, the composition root, constructs it and calls `apply_overrides()`, and passes it to nobody else — ADR-0009 §7.)
- **`InputResolver.get_bindings(action, device_kind) -> PackedStringArray` is read-only.** `UiService`, not each overlay, grabs focus for an overlay — source: ADR-0003, as amended by ADR-0008 §4
- **The resolver's capture mode is reached only through ADR-0008's `InputCapture` facade** (the remap screen). `InputBindingsValidator.validate_bindings(triples)` validates player overrides. Only `GameRoot` applies binding overrides to the resolver (`apply_overrides()`) — source: ADR-0003, as amended by ADR-0009 §7

**Game State & Scene Flow, revision 2026-10-23 (ADR-0002 §11, requested by ADR-0012)**
- **`request_in_mode_fade(callback)` is the fourth entry point**, legal only in `OVERWORLD`, with `phase == IDLE` and **no overlay open**; close the Dialogue first (`close_overlay()`), then request the fade on the same frame after `overlay_closed`. An invalid `callback` returns `REJECTED_INVALID_PAYLOAD` — source: ADR-0002 §11
- **The in-mode fade is OUT (`fade`) → zero-length SWAP that calls `callback` once, with no loader call → IN**; it emits only `transition_started(mode, mode)` and `transition_finished(mode)`, never `mode_exited`/`mode_entered`; `is_in_mode_fade()` is true between them. Input lock, Menu deferral, `is_save_safe() == false` and quit-waiting behave as for any transition — source: ADR-0002 §11
- **`register_camp(camp_id)` is the second input to `last_camp_id`**: only the Overworld mode calls it, only in `OVERWORLD`; an empty ID is logged and ignored; it emits no signal and marks unsaved progress (ADR-0009) — source: ADR-0002 §11

**Content Data record types added by ADR-0012**
- **`map` (`map_`), `encounter` (`enc_`) and `occupation_stage` (`ostage_`) are catalog record types, and `faction` gains `patrol_archetype_id`**; a map's scene path is derived as `res://scenes/maps/<map_id>/<map_id>.tscn`, never stored — source: ADR-0012 §3, ADR-0001

### Forbidden Approaches

**Content Data Definitions (ADR-0001)**
- **Never use `@export var x: OtherResourceType` for a cross-reference** — source: ADR-0001
- **Never put logic in a record class** beyond basic getters — source: ADR-0001
- **Never mutate a record's fields after load**, or use a record as live runtime state — source: ADR-0001
- **Never name lookups `get()`, `exists()` or `all()`** — `get` collides with `Object.get(property)` — source: ADR-0001
- **Never enumerate content files with `DirAccess`** — exported builds expose `.remap` companions — source: ADR-0001
- **Never fail fast on the first bad record** — source: ADR-0001
- **Never call `load_all()` from another autoload's `_init()`** — source: ADR-0001
- **Never rely on `Resource` loading alone to catch unknown or missing fields** — source: ADR-0001
- **Never resolve Feature-layer vocabularies inside `ContentCatalog`** — source: ADR-0001
- **Never treat `.godot/imported/` as content** — source: ADR-0001
- **Never store content as plain JSON files or `ConfigFile` sections** — source: ADR-0001

**Content Boot Ordering (ADR-0004)**
- **Never call `ContentCatalog.load_all()` from anywhere but `ContentBootstrap.run()`** — source: ADR-0004
- **Never let `src/data/` import `src/boot/` or any Feature-layer script** — source: ADR-0004
- **Never register a vocabulary from a static initializer the catalog triggers by referencing a Feature class** — source: ADR-0004
- **Never lazy-load the catalog on the first lookup** — hides ordering, breaks deterministic Content Error — source: ADR-0004
- **Never resolve a faction's rule class by reflection (`ProjectSettings.get_global_class_list()`)** — explicit registration costs one line per rule and validates every reachable rule — source: ADR-0011 (Alternative 1; amends ADR-0001)
- **Never add a cross-record validator phase**: a validator looks only at its own record and boot-time registries; cross-record checks go through `ref_ids` and the generic reference pass — source: ADR-0011 (Alternative 3), ADR-0004 §4

**Game State & Scene Flow (ADR-0002)**
- **Never call `SceneTree.change_scene_to_file()`, `change_scene_to_packed()` or `reload_current_scene()`** anywhere in the project — source: ADR-0002
- **Never use `SceneTree.paused`** to implement the Menu's time stop — source: ADR-0002
- **No system other than `GameStateMachine` (through its `SceneLoader`) may add, remove or free children of `ModeHost`/`OverlayHost`**, or set their `process_mode` — source: ADR-0002
- **Never call `BattleCore.retry_battle()` for Retry under Game State** — it full-heals the squad — source: ADR-0002
- **After ADR-0002 Migration Step 2, `ChapterFlow` must not construct `BattleCore`**, connect to `battle_ended`, or hold a fight-start snapshot — source: ADR-0002

**Input System (ADR-0003)**
- **Never use Godot's `InputMap`/`Input` singleton for gameplay actions** — it merges devices and can't express the GDD's per-axis arbitration rules — source: ADR-0003
- **Never make Input an autoload** — it holds mutable state, which the `mutable_autoload_singleton` stance (ADR-0002, Architecture Principle 4) forbids — source: ADR-0003
- **Never let a mode or overlay reach the Input System directly** — the `mode_direct_input_access` stance (ADR-0002) — source: ADR-0003
- **Never leave native `ui_*` navigation bound to devices** — breaks the input lock during transitions and overlays — source: ADR-0003
- **Never build a fully custom focus system** in place of native `Control` focus — throws away AccessKit (4.5+) integration — source: ADR-0003
- **Never use `event.device == 0` to mean mouse/keyboard** — since 4.7 they no longer report device `0` — source: ADR-0003 / `deprecated-apis.md`
- **No script other than `InputSystem` may override `_input`/`_unhandled_input` to read gameplay keys, or poll `Input.is_action_*`** — source: ADR-0003

**Game State revision (ADR-0002 §11, ADR-0012)**
- **Never fade the Overworld without going through the machine** — Game State's input lock, Menu deferral, save safety and `transition_finished` (which starts encounter grace) would all miss it — source: ADR-0012 (Alternative 6), ADR-0002 §11
- **Never write `last_camp_id` from anything but the machine** (`CampEntryPayload` or `register_camp`) — source: ADR-0002 §11, ADR-0012 §4

### Performance Guardrails
- **ContentCatalog**: loads once at boot, never per frame; every record stays resident for the session — source: ADR-0001
- **ContentCatalog load + validation**: median of 10 runs on 500 generated records under 1.0 s on the development PC (provisional) — source: `design/gdd/content-data-definitions.md` F5/AC-25
- **`GameStateMachine.tick()`**: a few comparisons per frame, no per-frame allocation — source: ADR-0002
- **Swap phase load**: bounded by `TransitionConfig`'s per-type budgets (0.5 s Retry, 1.0 s battle wipes, 1.5 s fades); an overrun logs a warning and never skips work — source: ADR-0002
- **Input**: one dictionary lookup per device event, negligible per `tick`; the binding table compiles once at boot in microseconds — source: ADR-0003

### Engine Verification Required
- **`ResourceLoader.list_directory()` (4.4, post-cutoff)**: verified in the editor on 4.7.2; **re-verify against an exported build** before the first real content migration ships — source: ADR-0001
- **Detach/re-attach via `remove_child`/`add_child` preserves state** (verified 4.7.2): `_ready()` fires once total, `Timer`/`Tween` freeze while detached/disabled and resume afterwards — source: ADR-0002
- ⚠️ **An `AnimationPlayer` under a disabled `ModeHost` holds and resumes** (probed; advisory E7, not yet folded in: ADR-0002 §5 still lists it as open verification item 3) — source: ADR-0002 Review History
- ⚠️ **A detached Overworld is orphaned on quit mid-battle** (advisory, not yet folded in, E8): `GameRoot` should free it on `NOTIFICATION_PREDELETE`/`WM_CLOSE_REQUEST` — source: ADR-0002 Review History
- **An autoload's `_ready()` runs AFTER the main scene's `_enter_tree()`** (verified 4.7.2; under `-s`, after `_initialize()`) — source: ADR-0004
- **`InputMap.action_erase_events()` + `Input.parse_input_event()` with an `InputEventAction` drives native `Control` focus/press on 4.7.2** (verified). Every injected `InputEventAction` reaches a sibling `_input()`, so the resolver must ignore `InputEventAction` — source: ADR-0003
- ⚠️ **Real Xbox/PlayStation/Nintendo pad names under SDL3 are not yet verified** (needs hardware); `generic` is the safe fallback — source: ADR-0003
- ⚠️ **Steam Input on the native Linux Deck shows "Steam Virtual Gamepad"** (advisory, not yet folded in, E9): `pad_style` needs a Deck/Steam row — source: ADR-0003 Review History

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems, physics, collision, the
Sprite & Camera Presentation system (3D dioramas, cameras, lighting), Stats &
Damage Resolution (`src/battle/stats/`) and Save/Load & Settings (`src/save/`)*

### Required Patterns

**Sprites (ADR-0005 §1–§2)**
- **Every character, enemy and comedy-VFX sprite is a `CharacterSprite` scene**, rooted on an `AnimatedSprite3D` used as node + frame source + culling bounds. `scale` stays `(1, 1, 1)`; never rotated — source: ADR-0005
- **On-screen size comes only from `T = max(1, floor(viewport_height / texel_base_lines))`.** No `pixels_per_unit` render parameter — source: ADR-0005
- **Mirroring is a shader flip uniform, never `flip_h`** (the override ignores it). A `no_mirror` animation uses an authored `_mirrored` variant instead — source: ADR-0005
- **`stop()` is called ONCE, in `setup()`, and never again while frames are being stepped.** `show_frame()` assigns `animation` (only if changed) before `frame`, or uses `set_frame_and_progress()` after the animation assignment — source: ADR-0005 (probed 4.7.2, E1 fix)
- **`CharacterSprite` sets the frame-texture uniform in the same call that changes `animation` or `frame`** — source: ADR-0005
- **Each `CharacterSprite` owns its own `material_override` `ShaderMaterial` instance** (one per sprite; a sampler can't be an `instance uniform`) — source: ADR-0005
- **Projection is computed by `SpriteProjection`, a pure, static, headless-testable function.** `vertex()` writes `POSITION` directly for a clip-space quad on the upright card — source: ADR-0005
- **Shader specifics (probed 4.7.2)**: RD backends' NDC is y-down; the quad corner comes from `VERTEX_ID` (never `UV`, which is an atlas region); `vertex()` also writes `VERTEX` and `NORMAL`; under a pitched camera, `fragment()` derives UV from `FRAGCOORD`; `custom_aabb` covers the quad at depth — source: ADR-0005
- **`ALPHA_SCISSOR_THRESHOLD` is set in `fragment()`; actors never use alpha-to-coverage or alpha antialiasing** (MSAA 2× is on) — source: ADR-0005
- **Actors use `render_mode ambient_light_disabled`.** Only lights whose cull mask includes `ACTORS` light them — source: ADR-0005
- **The rim is added only on the rim texel ring** (opaque, non-outline texels 4-adjacent to Outline Ink bordering transparency); never on the outline — source: ADR-0005
- **Actors have `cast_shadow = OFF`** and get a blob shadow instead — source: ADR-0005

**Stages and lighting (ADR-0005 §3–§5)**
- **Every 3D mode scene contains exactly one `DioramaStage`**, which owns the camera, environment, light rig and sky card — source: ADR-0005
- **Light rig**: `KeyLight` (cull `ACTORS`, no shadows), `SetLight` (cull `SET`, the ONLY shadow caster), `FillLight` (cull `SET`, no shadows). A practical that also lights actors adds `ACTORS` to its cull mask and is tagged `actor_lighting` — source: ADR-0005
- **The `Environment`'s ambient energy is 0, and its sky is never used** (the sky doesn't follow `frustum_offset`, observed). `SkyCard` (an unlit `MeshInstance3D`, tagged `sky`) is the only sky — source: ADR-0005
- **`DioramaStage` joins group `"active_diorama_stage"` on `_enter_tree()`**, leaves on `_exit_tree()`, and sets `camera.current = true` on `_enter_tree()` — source: ADR-0005
- **Every battle stage enters on profile `battle`** (never an entry profile named `boss_*`). The boss light is requested explicitly by the owning mode, never the Director, via `stage.request_profile()` — source: ADR-0005
- **The stage holds no `PresentationConfig` and no Director reference.** Profile lookup goes through `bind_profiles(resolver)`, set by the Director on `mode_entered` — source: ADR-0005
- **`PresentationDirector` applies the entry profile at `blend_time = 0` on `mode_entered`**, hidden behind the wipe; it skips the apply on a same-mode row (Retry) because the owning mode already set the light during SWAP — source: ADR-0005
- **`PresentationDirector` writes the global uniforms every frame, only through `GlobalUniformSink`.** Nothing may read a global uniform back from `RenderingServer` — source: ADR-0005
- **A blend requested with a `clock` runs from that clock, never a tween** (the takeover blend) — source: ADR-0005
- **`LightingProfile` and `PresentationConfig` are data (`.tres`).** Every lighting/FOV/camera/texel/timing value comes from them, never literals — source: ADR-0005

**Cameras (ADR-0005 §6)**
- **Battle camera: `PROJECTION_FRUSTUM`, pitch 0, `keep_aspect = KEEP_HEIGHT` ALWAYS.** Never `KEEP_WIDTH` under `PROJECTION_FRUSTUM` on 4.7.2 (CPU/GPU projections disagree, probed). `size` recomputes on `size_changed`; `frustum_offset` carries lens shift + hit-punch — source: ADR-0005
- **The camera's position, rotation and `near` never change in a fight; `size` changes only on a window resize** — source: ADR-0005
- **`SpriteProjection`'s `CameraState` builds its matrix via `Projection.create_frustum_aspect()`**, never `Camera3D.get_camera_projection()`. No test uses `unproject_position()` on a FRUSTUM camera — source: ADR-0005

**Clocks and layering (ADR-0005 §7–§8, §11)**
- **World shaders (the sky card's clouds included) read `mode_time` only, never `TIME`.** Covers shader files, embedded shader code and visual-shader Time nodes — source: ADR-0005
- **Core never imports Feature: `DioramaStage` and `CharacterSprite` must never reference `BattleReplayController`.** The owning mode connects controller signals and passes clocks as `Callable`s — source: ADR-0005
- **Boot validation registers `PresentationValidators`**: `sprite_set_exists`, `boss_profile_exists`, `required_animations`, `impact_frame`/`land_frame`, `intro` length vs `boss_hold`, no duplicate move-animation names, `PresentationConfig` load rules, `LightingProfile` rules, every flash source declaration — source: ADR-0005
- **Nothing may compile a rendering pipeline in play after Boot warm-up.** Boot warms every (mode, profile) combination's compiling parameters, and every canvas material used in play, in the MAIN viewport (never a differently-configured `SubViewport`) — source: ADR-0005
- **A profile must not switch a compiling parameter (§11) to a combination Boot didn't warm**; in play, profiles change only non-compiling parameters or switch among warmed combinations — source: ADR-0005
- **AC-64's "empty shader cache" state**: delete the engine's Vulkan pipeline cache in `user://` and the project's `.godot/shader_cache/` before measuring; both engine cache settings (`pipeline_cache/enable`, `shader_cache/enabled`) stay at their shipped `true` — source: ADR-0005 (E2 fix)

**Backend, output and AA (ADR-0005 §10)**
- **Screen-space AA (FXAA/SMAA) and TAA are off; MSAA 3D is 2×; HDR output is off; 3D render scale is 1.0, no upscaler** — source: ADR-0005
- **Backend is pinned to Vulkan on every target** (`driver.windows` and `driver.linuxbsd`). **Both `fallback_to_d3d12` and `fallback_to_opengl3` are set `false` explicitly** (both default `true` on 4.7.2, probed) — source: ADR-0005
- **The Steam Deck build is a native Linux export** (Godot's `Linux` preset, x86_64), never the Windows build under Proton — source: ADR-0005

**FlashGate and the capture tool (ADR-0005 §12–§13)**
- **Every large-area luminance source must have a `FlashSourceDecl` and book through `FlashGate.request()`/`book_reserved()`.** A discarded source's booking must be cancelled via `FlashGate.cancel()` — source: ADR-0005
- **The capture tool sets `SubViewport` MSAA, screen-space AA and the positional shadow atlas size explicitly** — a `SubViewport` does not inherit the project's settings (observed) — source: ADR-0005
- **Read the texel height as `get_viewport().size.y`** (full window pixels under ADR-0008's refit), never `get_visible_rect()` (logical units). Every `size_changed` listener must be idempotent: it runs twice per refit — source: ADR-0005 §1, ADR-0008 §9

**Stats & Damage Resolution (ADR-0007)**
- **`DamageResolver` stays static and stateless**: no member state, no `get_tree()`, no autoload, no `Time`, no global RNG. Every input arrives in the `ResolutionRequest`. The one exception is the registry's debug-only `_resolving_depth` counter — source: ADR-0007
- **Every `damage` or `heal` effect in a battle goes through `DamageResolver.resolve()`.** No system computes damage or heal amounts itself, or applies them to HP — source: ADR-0007
- **`Combatant.hp` is a read-only property.** Only the resolver's Apply step calls `_apply_hp()`, and only §2's allowlisted writers call `restore_vitals()` — source: ADR-0007
- **The resolver uses `BattleCore.rng`, and never draws for a heal, a skipped target or an invalid effect** — source: ADR-0007
- **Overrides run after F7, ordered by priority → `String(source_id)` → registration index** (index compared explicitly). Each result is clamped to `0 .. amount_cap`; only an override may produce 0 — source: ADR-0007
- **F2 floors with the `1e-6` epsilon** — source: ADR-0007
- **Every tuning number comes from `StatsConfig`, loaded only through `StatsConfig.load_or_default()`.** Tests compute expected values from the config, and each formula test also runs with a non-default config — source: ADR-0007
- **`ResolutionHooks` is rebuilt in every `start_battle()`**: clear, built-ins, then the faction hook. Never shared between battles or stored globally — source: ADR-0007
- **Modifiers and overrides never touch the registry or resolve anything** from inside `applies()`, `flat_for()`, `pct_for()` or `override()` — source: ADR-0007
- **A new damage modifier or override is registered, never added as a branch inside the resolver.** The resolver knows nothing about Defend, Viral Stunt or any faction — source: ADR-0007
- **`_resolve_move()` checks `can_afford()` before spending MP, for every actor** — source: ADR-0007
- **A non-resolving move changes no state, carries exactly one record, is appended to `outcome_log`, and is not emitted on `action_resolved`.** Every emitted outcome is `RESOLVED` (asserted at the emit site) — source: ADR-0007
- **`StatModifier.stat` is limited to `ATTACK`, `DEFENSE` and `SPEED`**; the resolver ignores and reports any other value — source: ADR-0007
- **Every non-void override (`applies`, `flat_for`, `pct_for`, `override`) returns on every path** — a miss fails the script load on 4.7 (probed) — source: ADR-0007

**Save/Load & Settings (ADR-0009)**
- **Saves and settings are JSON.** Saves are hashed two-line files in numbered slots under `user://saves/`, written atomically (`.tmp` → rename, with a `.bak`); settings are one `user://settings.json` — source: ADR-0009
- **A file over `max_file_bytes` is refused before parsing**, and top-level types are checked before any field is read — source: ADR-0009
- **The hash covers the exact body bytes written.** Never hash a re-serialized parsed object (`JSON.parse_string()` turns `5321` into `5321.0`) — source: ADR-0009
- **Every `FileAccess.store_*` result is checked** (it returns `bool` since 4.4). A failed write leaves the previous file and its `.bak` intact — source: ADR-0009
- **`SaveFileSystem.ensure_dirs()` runs before the first save.** File access goes through the injected `SaveFileSystem`; tests use the in-memory fake in `tests/unit/save/` — source: ADR-0009
- **One `SaveParticipant` per persisting system**, owning its section's schema and migrations:
  - `capture()` returns JSON-safe values only (`Vector2` → `[x, y]`, `StringName` → `String`);
  - `stage()` reads through `SaveReader` and has no side effects;
  - `commit()` cannot fail;
  - sections store catalog IDs, never record contents, resolved through `SaveReader.get_id()`.

  — source: ADR-0009
- **`save_key` values are permanent.** A schema change bumps `schema_version()` and adds a `migrate()` step; old steps are never deleted — source: ADR-0009
- **A load is preflighted, then committed in SWAP**: `read_slot()` → `preflight()` (stage every participant, no side effects) before any transition request; `commit_if_loaded()` through `SceneLoader.payload_commit` — source: ADR-0009 §6
- **Only `SaveService` writes under `user://saves/`; only `SettingsService` writes `user://settings.json`** — source: ADR-0009
- **No consumer holds `SettingsService`.** Each gets its narrow view (`UiSettings`, `FlashSettings`, `PresentationSettings`), built in `src/boot/settings_views.gd` in the composition root; the Battle mode gets `PresentationSettings` as `var presentation_settings` through `pre_setup`, and the replay speed settings are fields of that view; `SettingsService` imports no Presentation or Feature type — source: ADR-0009 §7
- **`SettingsService.set_value()` debounces writes** (`SettingsConfig.write_delay_s`, 0.5 s, real clock) and flushes immediately from `quit_hook`, on `NOTIFICATION_WM_CLOSE_REQUEST` and on `NOTIFICATION_APPLICATION_FOCUS_OUT`. Invalid fields are replaced by their `SettingsSchema` default and logged — source: ADR-0009 §7
- **New Game calls `SaveService.reset_all_to_new_game()` before `request_transition(OVERWORLD)`; Continue always targets the Overworld** — source: ADR-0009 §6

**Sprite & Camera Presentation, amended by ADR-0012**
- **The Overworld resolves its lighting profile before the stage enters the tree**: the map's `liberated_profile_id` when region-liberated, else the `occupation_stage` record's profile for the map's faction × stage, else the map's own; the mode never requests an entry profile in `_ready()` — source: ADR-0012 §7, ADR-0005 §4
- **An in-mode fade (`from == to`, no `mode_entered`) triggers no rebind and no profile apply**; the same-mode skip covers only same-instance `BATTLE → BATTLE` — source: ADR-0012 Ordering Note, ADR-0005 §4
- ⚠️ **ADR-0005 annotation text is still owed** (TR-overworld-017): faction × stage profiles, liberated profile, `sky_card`, interior-light constraints, leader-relative blur bounds, capture-ID tags incl. `SKY` — source: ADR-0005 Status

### Forbidden Approaches
- **Never render actor sprites as 2D `CanvasLayer` nodes over the 3D world** — breaks diorama lighting and the occlusion guarantee — source: ADR-0005
- **Never composite separate `SubViewport`s for set and actors** — pipeline risk, doubled passes — source: ADR-0005
- **Never use an orthographic camera for the battle stage** — loses the tilt-shift perspective staging — source: ADR-0005
- **Never let a mode scene light itself with no Director** — there must be one always-processing owner of the global uniforms — source: ADR-0005
- **Never size a sprite by a world-space `pixel_size` on a Y-locked billboard** (superseded revision 1: mixed pixel scale, the art bible's #1 failure) — source: ADR-0005
- **Never pitch the battle camera down to frame the ground while keeping the `Environment` sky** — leans sprites back, and the sky doesn't follow `frustum_offset` — source: ADR-0005
- **Never use `keep_aspect = KEEP_WIDTH` under `PROJECTION_FRUSTUM` on 4.7.2** — CPU and GPU projections disagree (probed) — source: ADR-0005
- **Never set the battle camera's `h_offset`/`v_offset` (they stay 0), and never use a translation or rotation shake** — a translation moves near and far depths by different amounts; the punch is `frustum_offset` only — source: ADR-0005
- **Never add a second `Camera3D` or `WorldEnvironment`** to a mode scene that already has a `DioramaStage` — source: ADR-0005
- **Never use `AreaLight3D`, HDR output, FXAA, SMAA, TAA, an upscaler, or a render scale below 1.0 without an amendment to this ADR** — source: ADR-0005
- **Never read a global shader uniform back from `RenderingServer`** — it returns null at runtime on 4.7.2 (observed) — source: ADR-0005
- **Nothing in `src/battle/stats/` may reference `BattleCore`, `FactionRule`, `BattleOutcome`, `Move`, `SquadSpecials` or any other Feature type**; `src/data/` never imports `src/battle/stats/` (validators are bound in `ContentBootstrap`) — source: ADR-0007
- **Never extend `FactionRule` with amount virtuals (`modify_amount()`/`override_amount()`)** — many ordered sources can't be expressed by one virtual on one object — source: ADR-0007 (Alternative 2)
- **Never build a global modifier registry (autoload)** — the right lifetime is one battle attempt — source: ADR-0007 (Alternative 3)
- **Never emit non-resolving outcomes on `action_resolved`** — log them only — source: ADR-0007 (Alternative 4)
- **Never pass anything under `user://` to `ResourceLoader`, `load()`, `str_to_var()`, `ConfigFile.load()`, `bytes_to_var_with_objects()` or `FileAccess.get_var()`** — a save must be inert; only JSON is inert by construction — source: ADR-0009 (Alternatives 1–2)
- **Never save with `ResourceSaver` / `.tres`, `ConfigFile`, `var_to_str` or `store_var`** — source: ADR-0009 (Alternatives 1–2)
- **Never put settings and saves in one file** — settings must be live from boot — source: ADR-0009 (Alternative 3)
- **Never give Save/Load a central schema** of other systems' data — breaks layering; each participant owns its section — source: ADR-0009 (Alternative 4)
- **Never restore save state in the target mode's `setup()` and roll back on failure** — stage first, then commit (cannot fail) — source: ADR-0009 (Alternative 5)

### Performance Guardrails
- **Battle draw calls**: at most **300** for all 3D passes (including `SetLight`'s shadow cascades) plus at most **100** for canvas/HUD (400 total, counted separately) — source: ADR-0005, `project.yaml` `performance.draw_call_limit`
- **Frame time**: p99 ≤ **16.6 ms**, worst ≤ **33 ms** over a scripted battle, on a GTX 1080-class desktop at 1920×1080 and on Steam Deck at 1280×800 — source: ADR-0005, `project.yaml`
- ⚠️ **Memory ceiling**: not yet set (`performance.memory_ceiling_mb` unset in `project.yaml`); P-14 reports peak RAM/VRAM so one can be set — source: ADR-0005
- **`DamageResolver.resolve()`**: **median** under **50 µs** per resolution in the release-build benchmark (8 modifiers, 2 overrides) (probed ~4.7 µs with 8 modifiers, 2 overrides); runs only inside `submit_action()`, never per frame — source: ADR-0007, `stats-damage-resolution.md`
- **Saves**: taken only at safe moments (a few ms for tens of KB); settings writes are debounced; at most three files per slot (`.json`, `.bak.json`, transient `.tmp.json`) — source: ADR-0009

### Engine Verification Required
- **`PROJECTION_FRUSTUM` + `frustum_offset`**: near-plane units, +y moves the image down (verified 4.7.2) — source: ADR-0005
- **`stop()` and assigning `animation` on `AnimatedSprite3D` both reset `frame` to 0** (verified 4.7.2) — source: ADR-0005 (E1)
- **The clip-space quad is pixel-exact with `frustum_offset` non-zero**, with upright-card depth, level and pitched (verified) — source: ADR-0005
- **`fallback_to_d3d12` / `fallback_to_opengl3` exist and default to `true` on 4.7.2** (verified) — source: ADR-0005 (E4)
- ⚠️ **`ALPHA_SCISSOR` discards in the depth prepass** (advisory, not yet folded in, E5): "early-z stays on" is overstated — performance only — source: ADR-0005 Review History
- ⚠️ **Shader Baker + global uniforms on a Linux export built from a Windows host is unchecked** (advisory, deferred to the first export, E10) — source: ADR-0005 Review History
- **`JSON.parse_string()` returns every number as `float`** (2^53 exact, 2^53 + 1 not); `JSON.stringify(obj, "", true)` sorts keys deterministically (probed 4.7.2) — source: ADR-0009
- **`DirAccess.rename_absolute(tmp, target)` replaces an existing target on Windows** (probed); on Linux it is POSIX `rename()` (REASONED) — ⚠️ probe on the Steam Deck export — source: ADR-0009
- ⚠️ **Owed before the first save story** (advisory, `architecture-review-2026-10-22b.md` F6–F8, not folded into ADR-0009): no fsync, and `read_slot` should fall back to `.bak` on `CORRUPT`, not only when main is missing; use `JSON.stringify(..., full_precision = true)` and store RNG state as a string; `NOTIFICATION_APPLICATION_FOCUS_OUT` as the Deck suspend path is NOT SOURCEABLE (hardware probe); `use_custom_user_dir` applies to editor and test runs, so `user://` tests could overwrite real saves — source: ADR-0009 Review History
- **Still to verify in Step 1**: `ambient_light_disabled` + key-only lighting on actors; manual frame stepping of `AnimatedSprite3D` (the frame reset is probed; a windowed render check remains); flip-based mirroring in the shader; the glow-input hook; which lighting parameters change a pipeline — source: ADR-0005, Verification Required items (12)–(16)

---

## Feature Layer Rules

*Applies to: secondary mechanics, AI systems, secondary features, the Battle
Replay Ownership controller that gates Turn Battle's outcomes behind
presentation, Turn Battle System and Faction Rule Modifiers*

### Required Patterns

**Content vocabulary (ADR-0001)**
- **Turn Battle System registers its EffectDescriptor types with `ContentCatalog` before validation; Faction Rule Modifiers owns rule-class resolution through `FactionRuleRegistry`** — source: ADR-0001, as amended by ADR-0011 (the Feature-layer side of the Foundation vocabulary rule)

**Turn Battle System (ADR-0010)**
- **`BattleCore` never extends `Node`, references the scene tree, awaits, or reads time.** Every collaborator comes through `_init`; it stays a pure, synchronous `RefCounted` — source: ADR-0010
- **`check_command(move, target) -> CommandCheck` has no side effects** (no state change, RNG draw, signal or log); gate 0 short-circuits. The command menu calls it to enable or disable options, and `submit_action()` uses the same check (returns `null` on a failed check) — source: ADR-0010 §2
- **Under Game State, a `BattleCore` is built only by `BattleFactory.build()`** in the Battle mode, from an `EncounterDescriptor` plus the party. Test and harness code may construct it directly — source: ADR-0010 §3
- **Only the Battle mode calls `report_battle_outcome()` / `report_results_done()`**, and only from `BattleReplayController`'s `*_after_replay` signals, in ADR-0006 §5's end-of-fight order — source: ADR-0010
- **New enum values are appended, never inserted** — source: ADR-0010
- **The transient flags are written only by the writers listed in ADR-0010 §7** — source: ADR-0010
- **Flee is a FLEE command category, a FLED terminal state and a fifth signal `battle_fled`**, released by the replay controller as an END-class marker. The flee rules stay provisional: a Flee-shipping story is blocked until `turn-battle-system.md` has a Flee section and a TR — source: ADR-0010 §5, ADR-0006 (amended by ADR-0010)
- **The characterization suite (ADR-0001 Migration Step 0) runs first in `tests/unit/battle/` and stays green through every migration step** — source: ADR-0010

**Faction Rule Modifiers (ADR-0011)**
- **`FactionRule` is one instantiable base class with neutral defaults and no mutable per-battle state.** Fields are written only in `_configure()`; the same applies to the modifiers and overrides it registers — source: ADR-0011
- **Rules are built only through `FactionRuleRegistry.create(faction, rule)`**, from a `FactionRule` record (`rule_class`, `params`, `texts`, `colors`, `ref_ids`). Every ID a rule's params name is also listed in `ref_ids` — source: ADR-0011 §4–§5
- **`specials_allowed()` and `move_allowed()` are side-effect-free and draw no RNG** — source: ADR-0011
- **`apply_round_upkeep()` may change only MP.** A rule never writes HP or Turn Battle's transient flags — source: ADR-0011
- **A rule draws randomness only from the `rng` argument** — source: ADR-0011
- **`choose_enemy_action()` returns `Array[EnemyAction]`** — source: ADR-0010, ADR-0011
- **A rule identifies combatants by `record_id`, `is_boss` or `faction_id`, never by `display_name`.** `Combatant.record_id` is immutable, set at construction, and never read by the resolver — source: ADR-0011, ADR-0007 (amended by ADR-0011)
- **Rule tuning, rosters, named attacks, colours and player-visible text are data.** Rule scripts declare no numeric tuning `const`s, colour constants or display strings; text templates are read through `LocText` — source: ADR-0011, ADR-0013
- **Every non-void override returns on every path** — a miss is a hard parse error on 4.7 that fails every dependent script (probed) — source: ADR-0011
- **A rule-record validator looks only at its record and the boot-time registry** — source: ADR-0011
- **A new rule class is added to `FactionRules.register_all()` with a validator**, and its ADR or story names that line — source: ADR-0011

**Battle Replay Ownership (ADR-0006)**
- **`BattleReplayController` is a `RefCounted` beside `BattleCore` (`src/battle/`).** The Battle mode constructs **one controller per Battle-mode instance**, surviving every Retry — source: ADR-0006
- **`BattleCore` and `BattleOutcome` must never be edited to add presentation awareness** — source: ADR-0006
- **Under Game State, the Battle mode owns its `BattleCore` for its whole life**, calls only `start_battle(false)`, never the default `start_battle()` or `retry_battle()` — source: ADR-0006
- **Controller construction and `enqueue_reveal_gate()` must happen before every `start_battle(false)`.** `enqueue_takeover()` comes after the gate and before `start_battle(false)` — source: ADR-0006
- **`open_reveal_gate()` is called only from the Battle mode's `transition_finished(BATTLE)` handler** — source: ADR-0006
- **First-entry order**: build → clear squad transients → controller → gate → takeover → `start_battle(false)` → `resync()` — source: ADR-0006
- **Retry order**: cancel (on `transition_started(BATTLE, BATTLE)`) → [SWAP] cancel again → restore HP/MP → request light → gate → takeover → `start_battle(false)` → `resync()` — source: ADR-0006
- **Every listener that shows battle state must reset to the displayed state on `display_resynced`** — source: ADR-0006
- **`BattleHud` and the Battle mode connect only to the controller's signals**, never directly to `BattleCore.turn_started`/`round_advanced`/`battle_ended` — source: ADR-0006
- **`BattleHud` reads HP/MP/status only through `get_display()`; the round only through `get_display_round()`** — source: ADR-0006
- **Presentation takes beat-driven frames, the punch's `t` and the takeover's `t_blend` only from the controller's three clock queries** (`get_windup_progress`, `get_post_impact_time`, `get_hold_time`). No separate `Tween`/`Timer`/`AnimatedSprite3D` playback for them — source: ADR-0006
- **Only the Battle mode's `_process` may call `advance(delta)`.** No `Timer`, `Tween`, `SceneTree` or `Time` access may be added to the controller — source: ADR-0006
- **Leftover `dt` is dropped, never carried, across clock steps** — source: ADR-0006
- **During a replay, `confirm`/`fast_forward`/`cancel` presses are consumed by the latch methods and never buffered or passed on** — source: ADR-0006
- **The Battle mode must call `cancel_pending_replay()` (and stop its end-of-fight hold) on every `transition_started` away from the current battle**, and `dispose()` from `_exit_tree()` — source: ADR-0006
- **Process order**: `advance(delta)` first, then push results down (`set_punch_offset_px`, `show_frame`, HUD refresh) — source: ADR-0006
- **Re-entrancy**: a handler must not call `cancel_pending_replay()`, `dispose()`, `submit_action()` or any queue method directly during emission; use `call_deferred()` — source: ADR-0006
- **`battle_speed_mult ≤ ff_mult − 0.25`** (load-time validated), so the latch always speeds a wind-up beyond Faster battle animations — source: ADR-0006
- **Hard prerequisite**: none of this can be built until ADR-0002 Migration Step 2 moves `BattleCore` construction out of `ChapterFlow` — source: ADR-0006

**Overworld Exploration & Encounters (ADR-0012)**

*Movement and the walk grid*
- **All overworld logic steps on one clock `ow_dt = min(delta, dt_max)`, accumulated only in Exploring**; `dt_max` is read from Presentation, never duplicated in `OverworldConfig`; sprite animation is driven from `ow_dt` too — source: ADR-0012 §2
- **Everything runs in `_process`, with pinned `process_priority`: `GameRoot` −20, `OverworldMode` −10, `FollowCamera` 0, `CharacterSprite`s +10**; nothing overworld runs in `_physics_process` — source: ADR-0012 §2
- **Movement goes through the pure static `GroundMover.step(pos, input_vec, dt, grid, cfg, speed, blocked_mask)`** with axis-separated collision against the baked `WalkGrid`; read input only from `machine.get_move_vector(self)` — source: ADR-0012 §2
- **Positions are ground-plane `Vector2`s (x east, y south), rendered at `Vector3(p.x, 0, p.y)`; logic never reads a 3D transform back** — source: ADR-0012 §1
- **Bake the `WalkGrid` once at map load** from the map scene's hidden, collision-disabled `WalkLayer` (`TileMapLayer` with `walk`/`zone` custom data), tag `SAFE` conservatively, then free the layer — source: ADR-0012 §2
- **Blocked cells change only through batched `WalkGrid.set_blocked(cells, on)`**, which updates both grids, invalidates stored paths and notice caches, and marks the 4-connected component labels for one relabel per frame — source: ADR-0012 §2
- **`AStarGrid2D.update()` only inside the bake; `region`, `cell_size` and `offset` frozen afterwards; debug builds assert `not is_dirty()` before every query; config pinned** (`DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`, octile, no jumping, `cell_size = cell_m`); `get_id_path(..., allow_partial_path = false)` from an origin snapped to the nearest symbol-legal cell — source: ADR-0012 §2
- **Marker ground positions come from the `x`/`z` of their transform relative to the map root, composed from local `transform`s; never read `global_*`** — markers are read before the map enters the tree — source: ADR-0012 §3

*Maps, entry and world state*
- **`OverworldMode._ready()` builds only per-visit state, in order**: `MapData` + stage + liberation → scene by ID convention → bake → markers (`min_stage`, caps sorted by `(min_stage, marker order)`) and blockers → `CharacterSprite`s → place party → `stage.profile_id` before tree. **It writes nothing to `WorldState`**: map, position, respawn and `stage_stored` are committed on `mode_entered(OVERWORLD)` — source: ADR-0012 §4
- **`WorldState` (injected `RefCounted`, never an autoload) is the single owner of map, position and facing (written every frame) and of state that outlives a visit** (`camp_returns`, `chapter_step`, resolved/opened/liberated per map, `stage_stored`, payoffs, interim `story_flags`); nothing per-frame emits a change signal or reaches the save path. It is created by `GameRoot` and assigned by the composite `pre_setup` injector; `OverworldMode._ready()` asserts it is non-null — source: ADR-0012 §4, ADR-0002 annotation (c)
- **Entry paths**: `MapEntryPayload` → marker, `on_map_reenter` respawn applied; `LoadedSave` → saved position, **no respawn**, relocate a now-blocked position by BFS (≤ 5 m, else first EntryPoint); `null` → New Game — source: ADR-0012 §4
- **Map change swaps to a fresh instance: it detaches the old mode, adds the new one, and frees the old only on success** (rollback re-adds it); `ModeHost` never holds two live modes. All four signals fire with `from == to == OVERWORLD`, and `PresentationDirector` applies the new map's entry profile — source: ADR-0012 §4, ADR-0002 §2 and annotation (a)
- **The camp return point is derived, never stored twice**: `camp_returns[machine.last_camp_id]`, falling back to the region default camp; registering a camp checks its ID against the map's CampSpots first; Retreat is `choose_retreat()` → CAMP — source: ADR-0012 §4
- **The current chapter step is `WorldState.chapter_step`, written only by `OverworldMode`**; the static step list is interim `ChapterSteps` data — source: ADR-0012 §8, ADR-0002 §8

*Encounters and symbols*
- **Encounters start only through `start_encounter(enc_id, source)` from an `encounter` record**; a rejected request leaves the touched symbol in contact pending — source: ADR-0012 §5
- **Symbol AI lives in the pure `SymbolBrain`** (sub-states, notice with cheap checks first then a bounded uniform-cost search, `path_dist` upper bound with a +∞ gap after SAFE, pending paths, final approach only over legal cells, facing hysteresis, Static `start_on`) — source: ADR-0012 §5
- **Notice searches, repaths and Returning paths share `repath_per_frame_max` through a round-robin cursor** — source: ADR-0012 §5
- **Per-frame order: leader → exits (enter-edge only) → symbols in marker order → swept contact (eligibility after steps) → interaction**; contact is a swept circle test, never a physics query — source: ADR-0012 §5
- **Two-step thaw**: all state changes in `on_thawed` under the wipe; on `transition_finished`, grace and Noticing/Chasing → Returning after every transition, but on-screen liberation and the payoff card only when `pending_thaw` is set — source: ADR-0012 §5
- **Interaction is one `probe()` (nearest eligible target; ties NPC → CampSpot → Static symbol → Interactable) that drives both the prompt and `confirm`** — source: ADR-0012 §6, Overworld GDD rule 3 / AC-7a
- **A failed checkpoint's redirect closes the Dialogue and then calls `machine.request_in_mode_fade(callback)`; the callback places the leader at the return marker, snaps the camera and followers, and writes `WorldState` itself (the machine ticks before the mode)** — source: ADR-0012 §2, §6

*Data and validation*
- **Records never contain file paths; tuning comes from `OverworldConfig` or records, validated by `OverworldConfig.validate()` (invariants I1–I18, each error names its ID)** — source: ADR-0012 §9
- **`tools/ci/validate_maps.gd` runs after `validate-content.gd`**, runs `ContentBootstrap.run()` first, loads and bakes every map, and asserts every [D] criterion of the Overworld GDD — source: ADR-0012 §3
- **Player-facing overworld text (posters, decrees, cards, barks) is `LocText`** — source: ADR-0012 Guidelines, ADR-0013
- **Test fixtures that build a `TileSet` in code add the source to the `TileSet` before setting custom data** (probed) — source: ADR-0012 Guidelines
- **Randomness comes only from `OverworldMode`'s own seeded `RandomNumberGenerator`** — source: ADR-0012 Guidelines
- **Overworld tests live in `tests/unit/overworld/` (and `data/` for [D] checks), with fixture grids and an injected clock and RNG; `SymbolBrain` is steppable without the scene tree** — source: ADR-0012 Guidelines
- **MVP encounters come only from visible symbols; zones stay in code and data, and CI asserts `zone_rate = 0` on every MVP map** — source: ADR-0012 Summary, §3 `MapData`
- **Continuous movement is the default; whole-cell stepping exists only as a `GroundMover` fallback** — source: ADR-0012 (Alternative 2)

### Forbidden Approaches
- **Never add a "replay done" release gate inside `BattleCore` itself** — pulls animation timing into the headless core — source: ADR-0006
- **Never implement the replay with `await` chains or a local flag inside `BattleHud`** — no single testable owner, no single clock — source: ADR-0006
- **Never apply an outcome's `hp_delta` via per-target delta arithmetic for displayed HP** — wrong for party heals, blind to MP upkeep — source: ADR-0006
- **Never split the replay timing mechanism between this ADR and the GDD** — two reviews found them contradicting each other in at least five places — source: ADR-0006
- **Never add a time-stamped press guard inside the controller** — duplicates the Input System's one-`pressed`-per-press guarantee — source: ADR-0006
- **Never change `battle_ended(won: bool)` to carry a result enum** — Fled is the additive fifth signal `battle_fled`; revisit only if a fourth end state appears — source: ADR-0010 (Alternative 2)
- **Never resolve Flee in the Battle mode, outside `BattleCore`** — every command goes through `BattleCore` and the replay — source: ADR-0010 (Alternative 3)
- **Never make `BattleCore` asynchronous** (await between actions) — source: ADR-0010 (Alternative 4), ADR-0006
- **`BattleCore`, the Battle mode, `SquadSpecials` and every HUD widget never reference a rule subclass** (`BureaucratiaRule.`, `MegaCorpRule.`, `is BureaucratiaRule`, `get_script()`, class-name strings) **or compare faction IDs to change behaviour.** The CI grep flags any such reference outside `src/battle/factions/` — source: ADR-0011, ADR-0010
- **Never make a rule stateful** — statelessness is what makes Retry free; derive memory from combatant state, or add rule state to the Retry snapshot through a later ADR — source: ADR-0011 (Alternative 6)
- **Never put rule text in code as `tr()` keys** — templates live in the record — source: ADR-0011 (Alternative 5)
- **Never add a typed parameter record per rule class** — one `faction_rule` record type with per-class validators keeps factions as content — source: ADR-0011 (Alternative 4)

**Overworld Exploration & Encounters (ADR-0012)**
- **Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D** (`CollisionObject2D/3D`, `SoftBody3D`, `RayCast*`, `ShapeCast*`, `SpringArm3D`, joints, `PhysicalBoneSimulator3D`, the deprecated `TileMap`, any `CSGShape3D` in a shipped map, a `GridMap` with a non-zero `collision_layer` or `collision_mask` or with item shapes, a `TileMapLayer` with collision on) — reopens the Jolt risk and needs a physics world in tests; `validate_maps.gd` enforces it — source: ADR-0012 §2, §3 (Alternatives 1 and 3; probe item 8)
- **Never configure encounters inline on scene markers** — enemy IDs would escape catalog validation — source: ADR-0012 (Alternative 4)
- **Never store a scene path on `MapData`** — breaks Content Data Rule 3 — source: ADR-0012 (Alternative 5)
- **Never call `AStarGrid2D.update()` after the bake, or change `region`/`cell_size`/`offset`** — a rebuild clears every solid, and a dirty grid returns empty paths silently — source: ADR-0012 §2 (probed)
- **Never read a marker's `global_position` during map setup** — out of the tree it returns the origin — source: ADR-0012 §3 (probed)
- **Never write `WorldState` from `OverworldMode._ready()`** — a rolled-back map change would leave it naming the wrong map — source: ADR-0012 §4

### Performance Guardrails
- **CPU**: negligible — one queue append, one plan and one snapshot (~8 records) per emitted signal; one `advance()` per frame of constant work — source: ADR-0006
- **Memory**: one controller per Battle-mode instance; the queue holds at most one replay's entries — source: ADR-0006
- ⚠️ **Snapshot cost grows with battle size** (~8 records per entry at 8 actors); revisit above ~50 combatants — source: ADR-0006
- **`check_command()`**: a handful of calls per turn open, microseconds each, no per-frame work; `BattleFactory`'s catalog lookups run in SWAP, bounded by the enemy count — source: ADR-0010
- **Faction rules**: `create()` once per battle, during SWAP; per-turn call count unchanged — source: ADR-0011
- **Overworld symbol stepping + notice searches + repaths**: ≤ 2.0 ms per frame at p99 on the GTX 1080-class PC and the Steam Deck — source: `performance.per_system.overworld_ms` in project.yaml, ADR-0012 Performance, Overworld GDD AC-46
- **Overworld memory**: ~1 byte per walk cell plus a 4-byte component label (~200 KB at 200×200), plus `AStarGrid2D`'s own storage (~1–2 MB at that size); the detached Overworld stays resident during battles — source: ADR-0012 Performance
- **Overworld load**: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)
- **Component relabel**: one full pass costs ~0.83 ms on 60×60 (probed); batch `set_blocked` and relabel at most once per frame — source: ADR-0012 §2

### Engine Verification Required
- ⚠️ **The boss-light `clock` lambda outlives `dispose()`** (advisory E6, not yet folded in): `DioramaStage` should drop its `clock` when the blend completes and on `_exit_tree` — source: ADR-0006 Review History
- **Hidden, collision-disabled `TileMapLayer` under a `Node3D` creates 0 physics objects, and `get_used_cells()`/`get_custom_data()` read the walk data** (probed 4.7.2) — source: ADR-0012 Engine Compatibility (items 1–2)
- **After a stall, `_process` delta reached 0.133 s (`max_physics_steps_per_frame` 8 / 60), so `dt_max` ≤ 0.10 still binds** (probed 4.7.2) — source: ADR-0012 Engine Compatibility (item 6)
- **`GridMap.collision_layer` defaults to 1; `SoftBody3D`, `RayCast3D` and `ShapeCast3D` are not `CollisionObject3D`s, so the physics ban lists them by class** (probed 4.7.2) — source: ADR-0012 Engine Compatibility (item 8)
- **`AnimationMixer` manual callback mode plus `advance()` exist**, which the `ow_dt` animation rule relies on (probed 4.7.2) — source: ADR-0012 Engine Compatibility (item 13)
- **`AStarGrid2D`: `update()` rebuilds only when dirty; dirty queries log "Grid is not initialized" and return `[]`; a solid origin returns `[]` even with `allow_partial_path`** (probed 4.7.2) — source: ADR-0012 Engine Compatibility (items 5, 10)
- **`process_priority` sorts all nodes globally, ignoring parent/child order** (probed 4.7.2) — source: ADR-0012 Engine Compatibility (item 11)
- **`CSGShape3D.bake_static_mesh()` returns a mesh only one frame after tree entry** (probed 4.7.2) — source: ADR-0012 Engine Compatibility (item 13)

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, animations*

Rules that touch Presentation but are owned by another ADR (the flash gate,
`mode_time`, the texel scale) are listed under Foundation and Core above, where
their owning ADR sits.

### Required Patterns

**UI Framework (ADR-0008)**
- **`UiService` (`src/ui/ui_service.gd`, a `Node` under `GameRoot/Services`, `PROCESS_MODE_ALWAYS`) is the one UI owner and the second and last holder of the `InputResolver`.** It is not an autoload and holds no game state — source: ADR-0008 §1
- **Every concrete mode and overlay gets a `UiContext` through ADR-0002's `pre_setup` hook.** Only concrete mode and overlay scripts declare `var ui: UiContext`; `GameMode` and `GameOverlay` never declare or import a UI type — source: ADR-0008 §2
- **The command menu, target selection, Defeat Prompt and results screen contain a `FocusScope` and route menu actions through `MenuGuard.filter()`, then `UiNavigator.route()`.** Every other screen that takes menu input contains a `FocusScope` and routes through `UiNavigator` — source: ADR-0008
- **A screen never calls `grab_focus()` from its own `_ready()` on open**; `UiService` grabs focus on the announcement — source: ADR-0008 §5
- **Every `grab_focus()` call passes `hide_focus` explicitly**: `true` for pointer-driven grabs, the device rule of §5 otherwise (key and pad visible; refusal never reveals) — source: ADR-0008 §5
- **`UiNavigator` calls only `Input.parse_input_event()` with a `ui_*` `InputEventAction`, and injects press and release together** — source: ADR-0008 §3
- **Widgets get the device, style and glyphs only from `UiContext.prompts`.** No widget holds or receives the `InputResolver` or the `GameStateMachine` — source: ADR-0008 §4
- **Every overlay root has a full-rect `MenuBackdrop` with `MOUSE_FILTER_STOP` as its first child** — source: ADR-0008, ADR-0003
- **`screen_root`, every overlay root and every direct `Control` child of `TransitionLayer` are plain `Control`s (or `CanvasLayer`s), never `Container`s** — a `Container` collapses the full-rect blockers (probed) — source: ADR-0008 §6
- **Window stretch: `canvas_items`, `aspect = expand`, `scale_mode = integer`, base 640×360, written explicitly into `project.godot`.** The first-launch window override is 1280×720 — source: ADR-0008 §9
- **The stretch is refit only by `UiService.refit_canvas()`**: `f = max(1, floor(min(W/640, H/360)))`, `content_scale_size = (W div f, H div f)`. It is driven by the per-frame `get_window().size` comparison in `UiService._process` (plus once in `setup()`), never by `size_changed` alone. `setup()` sets `get_window().min_size = Vector2i(640, 360)` — source: ADR-0008 §9 (22c E1/E2)
- **Every screen anchors to the full rect and lays out with containers**; extra logical space goes to margins or expanding containers, never to cropped content — source: ADR-0008 §9
- **Positions over actors go through `ui.world_to_ui()`** (`viewport.get_final_transform().affine_inverse() * p`), owned by `UiService` — source: ADR-0008 §9
- **A HUD lives under a `CanvasLayer` (layer 1) inside its mode scene**, never under `OverlayHost` and never in a 3D viewport. Overlays are layer 10, transitions layer 20 — source: ADR-0008 §9, ADR-0002
- **Colours, fonts and styleboxes come from `data/ui/ui_theme.tres`** (`gui/theme/custom`). The live text scale (1.0 / 1.25 / 1.5 from `UiSettings`) is applied by `UiService` through `Theme.set_font_size()`. Every wrapping `Label`/`RichTextLabel` uses `AUTOWRAP_WORD_SMART` — source: ADR-0008 §9
- **An interactive element is a native `Control`, or a focusable custom control that sets `accessibility_name`** — source: ADR-0008 §10
- **UI animations run on the real clock.** UI shaders under `OverlayHost`/`TransitionLayer` may use `TIME`; mode-HUD shaders must not — source: ADR-0008, registry `world_shader_time`
- **Every in-play canvas material is listed in `warmup_materials()`** — source: ADR-0008 §8, ADR-0005 §11
- **The replay indicator click is its own signal, never `confirm`** — source: ADR-0008 §12, ADR-0006
- **Unit tests in `tests/unit/ui/`** (injected clock, held-set `Callable`, stub focus owner) cover `MenuGuard`, the focus stack, the held-direction mirror, the pointer counter and `UiNavigator`'s mapping and focus-bound check — source: ADR-0008

**Localization (ADR-0013)**
- **Player-visible text is English source text.** In records it lives in a field listed in `LOC_FIELDS`; in code it goes through `tr()`/`tr_n()` with a literal, non-empty `<screen>.<purpose>` context; in scenes it uses automatic translation, with `translation_context` set where the English is ambiguous or the string is a joke — source: ADR-0013 §1
- **Display code reads record text through `LocText.of(record, field)` / `of_key()` / `fmt()`** (contexts `<record_id>.<field>[.<key>]`) — source: ADR-0013 §3
- **Each control is translated exactly once.** A control whose text code sets has `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED`, set on the leaf control that shows the code-set text, never on a container (`INHERIT` children, tooltips included, stop translating too). A fixed child under a code-set widget sets `AUTO_TRANSLATE_MODE_ALWAYS`. A `.tscn` value overrides an `_init()` assignment — source: ADR-0013 §1 (22b F4, 22c E6), ADR-0008 §11
- **Translatable text uses named `{placeholders}`** — source: ADR-0013
- **Screens that set text in code re-apply it on `NOTIFICATION_TRANSLATION_CHANGED`** — source: ADR-0013
- **Logs, IDs, validation errors and the Content Error screen are not translated** — source: ADR-0013
- **A record or field rename is followed by `apply_remap.gd` on every `.po`** — source: ADR-0013
- **Every UI story retains windowed pseudolocalization screenshots** (about 40% expansion, accents and brackets, at 640×360 and text scale 1.5) in `production/qa/evidence/`; a headless run can't capture them — source: ADR-0013 §6
- **`GameRoot` applies ADR-0009's `locale` setting with `TranslationServer.set_locale()` before Title.** An empty setting means the best match for `OS.get_locale_language()` among the loaded locales, else `en`. The runtime locale list is `TranslationServer.get_loaded_locales()` plus `en`, never `project.yaml` — source: ADR-0013 §7
- **Every `LOC_FIELDS` text on a joke-bearing type** (QuirkState `description`/`rule_text`, Combo `punchline_text`/`codex_text`, Move `flavor_text`, `FactionRuleData.texts`) **has a `loc_note` author-note companion** saying what the joke is, its target and tone, and whether to adapt or translate — source: ADR-0013 §9
- **Extraction and checking are project GDScript tools run headlessly** (`extract_records.gd`, the scene and code extractors, `tools/loc/check_loc.gd` in CI); the editor's POT generation is not used — source: ADR-0013 §2, §5

### Forbidden Approaches
- **Never call into `Input` outside `src/input/input_system.gd` and `src/ui/ui_navigator.gd`** — source: ADR-0008, ADR-0003
- **Never build a custom focus graph** — 4.6 keeps a single focus owner, so native focus is enough — source: ADR-0008 (Alternative 1), ADR-0003
- **Never implement the guard and focus rules per screen** — the rules span screens, and a convention can't hold the focus stack — source: ADR-0008 (Alternative 2)
- **Never make the UI an autoload** — source: ADR-0008 (Alternative 3)
- **Never add resolver signals for pointer motion or `nav_*` release** — `UiService` polls `pointer_position` / `get_move_vector()` once a frame; `nav_*` stays press-only — source: ADR-0008 (Alternative 5)
- **Never use `viewport` stretch, or a 1920×1080 base with fractional scaling** — integer `canvas_items` keeps sharp fonts, native 3D and ADR-0005's texel grid — source: ADR-0008 (Alternatives 6–7)
- **No script other than `UiService.refit_canvas()` sets `content_scale_size`, and no screen reads a fixed 640×360** — source: ADR-0008 §9
- **Screen scripts never declare colour or font-size `const`s**; the existing `BattleHud` constants move to the theme in its migration story — source: ADR-0008
- **Never show a key, and never invent a translation context** outside the two schemes — source: ADR-0013
- **Never use `%s` or concatenate display text** — source: ADR-0013, ADR-0008
- **Never use string keys with a CSV table, or CSV in place of `.po`** — fuzzy entries keep stale jokes off screen — source: ADR-0013 (Alternatives 1, 3)

### Performance Guardrails
- **HUD**: counts against the ≤ **100** canvas draw-call budget; the Menu blur adds one screen copy and one draw, only while open; UI materials compile in Boot warm-up, not on first use — source: ADR-0008, ADR-0005
- **Localization**: one lookup per displayed string when it is set, never per frame; `.po` files are baked at export — source: ADR-0013

### Engine Verification Required
- **`size_changed` fires only when the stretched size changes**: a resize that keeps `f` (1366×768 → 1920×1080) fires nothing; setting `content_scale_size` in a handler re-fires it once (probed 4.7.2) — source: ADR-0008 Verification item 13
- **A mouse click gives hidden focus** (`has_focus()` true, `has_focus(true)` false, no focus stylebox); injected `ui_*` navigation from hidden focus moves and reveals it natively (probed) — source: ADR-0008 Verification items 11, 14
- **POT generation is editor-GUI-only on 4.7.2** (no CLI flag, probed); `tr(source, context)` and `tr_n()` with context work; fuzzy `.po` entries fall back to English (probed) — source: ADR-0013
- **Still to verify**: dynamic fonts stay sharp under `canvas_items` at 3× and 4×; `Viewport.get_final_transform()` mapping; a hand-dragged resize (only code-driven resizes were probed); an exported build loads the `.po` translations — source: ADR-0008 items 9, 10, 13; ADR-0013 item 8
- ⚠️ **`pointer_*` during `MenuGuard`** (advisory 22b F9, not folded in): `InputSystem._input` sees a click before the GUI, so a click on `GuardBlocker` still emits `pointer_confirm` — source: ADR-0008 Review History

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example | Source |
|---------|-----------|---------|--------|
| Classes | PascalCase | `ContentCatalog` | `naming.classes` in project.yaml |
| Variables | snake_case | `move_ids` | `naming.variables` in project.yaml |
| Signals/Events | past tense | `catalog_loaded` | `naming.signals` in project.yaml |
| Files | snake_case | `content_catalog.gd` | `naming.files` in project.yaml |
| Scenes | snake_case | `battle_hud.tscn` | `naming.scenes` in project.yaml |
| Constants | SCREAMING_SNAKE | `MAX_HP_CAP` | `naming.constants` in project.yaml |

### Performance Budgets
| Target | Value | Source |
|--------|-------|--------|
| Framerate | 60 fps | `performance.target_framerate` in project.yaml |
| Frame budget | 16.6 ms | `performance.frame_budget_ms` in project.yaml |
| Draw calls | 400 total (300 3D + 100 canvas) | `performance.draw_call_limit` in project.yaml (2026-10-22 decision; was 2000, now a battle-measured budget — ADR-0005) |
| Frame time p99 | 16.6 ms | `performance.frame_time_p99_ms` in project.yaml (ADR-0005) |
| Frame time worst | 33 ms | `performance.frame_time_worst_ms` in project.yaml (ADR-0005) |
| Overworld share (p99) | 2.0 ms | `performance.per_system.overworld_ms` in project.yaml (2026-10-23 decision; ADR-0012, Overworld GDD AC-46) |
| Memory ceiling | not configured | `.claude/docs/technical-preferences.md` (`[TO BE CONFIGURED]`); ADR-0005 defers it to P-14's measured peak |

### Approved Libraries / Addons
- None configured yet — source: technical-preferences.md. (gdUnit4 is the test framework named in `.claude/docs/coding-standards.md` CI rules; install it from the editor's Asset Store workspace — source: `current-best-practices.md` § Editor Workflow 4.7.)

### Forbidden Patterns
- None configured yet — source: technical-preferences.md. (Per-ADR forbidden approaches are listed under each layer above.)

### Forbidden APIs (Godot 4.7.2)
These are deprecated or renamed in the pinned version. Use the replacement.

**This project is no longer 2D-only.** ADR-0005 renders the Sprite & Camera
Presentation system inside 3D dioramas (`Camera3D`, `DirectionalLight3D`,
`MeshInstance3D`, `AnimatedSprite3D`), and `project.yaml` names Jolt as the
physics engine. ADR-0012 (Accepted) forbids every physics node in the
Overworld, so the Jolt row applies only if a physics body is ever
added. 3D rows are no longer excluded on the
old "2D project" basis. The 2D rows stay: 2D modes and the 2D `Control` HUD
still exist.

- `TileMap` → `TileMapLayer` (4.3)
- `VisibilityNotifier2D` → `VisibleOnScreenNotifier2D` (4.0)
- `YSort` → `Node2D.y_sort_enabled` (4.0)
- `Navigation2D` → `NavigationServer2D` (4.0)
- `get_world()` → `get_world_3d()` (4.0) — relevant now that 3D mode scenes exist (ADR-0005)
- `GodotPhysics3D` for new projects → `Jolt Physics 3D` — relevant: `engine.physics` is Jolt (`project.yaml`); ADR-0002 §4 assumes any Overworld physics runs in Jolt
- `yield()` → `await signal` (4.0)
- `connect("signal", obj, "method")` / string-based `connect()` → `signal.connect(callable)` (4.0)
- `instance()` / `PackedScene.instance()` → `instantiate()` (4.0)
- `OS.get_ticks_msec()` → `Time.get_ticks_msec()` (4.0)
- `duplicate()` for nested resources → `duplicate_deep()` (4.5)
- `AnimationPlayer.method_call_mode` → `AnimationMixer.callback_mode_method`; `AnimationPlayer.playback_active` → `AnimationMixer.active` (4.3)
- `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` → `UPDATE_WIDTH_UNIT`; `add_image()`/`update_image()` `width_in_percent`/`height_in_percent` → `width_unit`/`height_unit` (4.7)
- `DisplayServer.AccessibilityLiveMode` → `AccessibilityServer.AccessibilityLiveMode` for `Control.accessibility_live` (4.7)
- `AudioEffectSpectrumAnalyzer.tap_back_pos` — removed (4.7)
- `event.device == 0` to detect mouse/keyboard → `event is InputEventMouse`/`InputEventKey`, or `InputEvent.DEVICE_ID_MOUSE`/`DEVICE_ID_KEYBOARD` (4.7) — also required by ADR-0003
- `$NodePath` inside `_process()` → an `@onready var` cached reference
- Untyped `Array`/`Dictionary` → `Array[Type]`, typed `Dictionary[K, V]` (probed on 4.7.2, ADR-0006) and typed variables. Documented exception: ADR-0005 §5's ID→path profile and sprite-set tables are untyped `Dictionary`s on purpose, with a loader check on key and value types
- When writing shaders: `Texture2D` in `Shader.set_default_texture_parameter()`/`get_default_texture_parameter()` → `Texture` (4.4)
- `VisibilityNotifier3D` → `VisibleOnScreenNotifier3D` (4.0)
- `Navigation3D` → `NavigationServer3D` (4.0)
- `Skeleton3D` signal `bone_pose_updated` → `skeleton_updated` (4.3)
- `EditorSceneFormatImporterFBX` → `EditorSceneFormatImporterFBX2GLTF` (4.3)
- Source: `docs/engine-reference/godot/deprecated-apis.md`

### Required Engine Patterns (Godot 4.5–4.7)
- **An override of a typed method needs an explicit `return`** (it inherits the return type in 4.7) — source: `current-best-practices.md` § GDScript (4.7); also ADR-0002, ADR-0005
- **Assign a whole packed array when its property setter must run**; `arr[i] = v` no longer calls the setter (4.7) — source: `current-best-practices.md` § GDScript (4.7)
- **Lambdas capture locals by value**: share state through a Dictionary, Array or object — source: `current-best-practices.md` § GDScript (4.5+)
- **UI focus (4.6+) has one focus owner (`gui_get_focus_owner()`), plus a hidden-focus state**: a click focuses with hidden focus, and `grab_focus(hide_focus)` chooses per call. Hover is a separate visual state that never moves focus by itself. Probed on 4.7.2. `current-best-practices.md` § UI describes it as two separate focuses, which the probe contradicts (reference correction owed, 22b F10) — source: ADR-0008 §5, Verification items 3 and 11
- **The root `size_changed` signal fires only when the stretched size changes** — a resize that keeps the integer factor fires nothing; poll `get_window().size` where every resize matters — source: ADR-0008 Verification item 13
- **`auto_translate_mode = DISABLED` is inherited by `INHERIT` children** (tooltips included); `Node.AUTO_TRANSLATE_MODE_DISABLED` is value 2 — source: ADR-0013 §1; the value is from `architecture-review-2026-10-22c.md` E6
- **`FileAccess.store_*` returns `bool` (4.4+)** — check every result — source: ADR-0009
- **`JSON.parse_string()` returns every number as `float`** — never hash or compare a re-serialized parsed object — source: ADR-0009
- **A non-void override missing a `return` on any path is a hard parse error on 4.7 that fails every dependent script** (probed), not a warning — source: ADR-0011, ADR-0007
- **`CanvasItem` lines have no antialiasing feather in 4.7** — source: `current-best-practices.md` § Rendering (4.7)
- **Search GDScript with `glob: "*.gd"`**, never `rg --type gdscript` — source: `current-best-practices.md` § Tooling
- **Parse-check scripts with `res://.claude/scripts/godot-parse-check.gd`**, not `--check-only` or `--import` — source: `current-best-practices.md` § Command Line
- **An autoload's `_ready()` runs AFTER the main scene's `_enter_tree()`** (verified 4.7.2, not before, as ADR-0001 originally assumed) — source: ADR-0004
- **`stop()` and assigning `animation` on `AnimatedSprite3D` both reset `frame` to 0** — order calls accordingly — source: ADR-0005 (E1)
- **`keep_aspect = KEEP_WIDTH` is broken under `PROJECTION_FRUSTUM` on 4.7.2** (CPU/GPU projections disagree) — always use `KEEP_HEIGHT` — source: ADR-0005
- **`RenderingServer.global_shader_parameter_get()` returns null at runtime on 4.7.2** — never read a global uniform back; write only through a sink — source: ADR-0005
- **`fallback_to_d3d12` and `fallback_to_opengl3` both default to `true` on 4.7.2** — set both `false` explicitly when pinning a backend — source: ADR-0005 (E4)
- **A `SubViewport` does not inherit the project's MSAA, screen-space AA or positional shadow atlas size** — set them explicitly — source: ADR-0005
- **Both engine shader/pipeline cache settings (`pipeline_cache/enable`, `shader_cache/enabled`) default to `true` on 4.7.2** — source: ADR-0005 (E2)
- **Typed `Dictionary[K, V]` compiles on 4.7.2** (probed; not sourced in the engine reference) — prefer it over untyped `Dictionary`, except ADR-0005 §5's ID→path tables — source: ADR-0006, ADR-0005

### Cross-Cutting Constraints
- **Never use `Engine.time_scale`, in any layer** (as `SceneTree.paused` is already banned): time stops only through Game State (`ModeHost` disabled, mode time) — source: ADR-0012 Ordering Note, ADR-0002 §5
- **Gameplay values are data-driven, never hardcoded**; with ADR-0001 the data lives in `ContentCatalog` records — source: `.claude/docs/coding-standards.md`, ADR-0001
- **Dependency injection over singletons**, with `ContentCatalog` as the one documented exception — source: `.claude/docs/coding-standards.md`, ADR-0001
- **Doc comments on every public API** — source: `.claude/docs/coding-standards.md`
- **A `RefCounted` logic core (`GameStateMachine`, `InputResolver`, `BattleReplayController`, `BattleCore`, `DamageResolver`, `FactionRule`) never touches the scene tree, an autoload by name, `Time` or `Engine` directly.** Collaborators and time enter only through injection (`_init`, `tick(delta)`, `advance(delta)`) — source: ADR-0002, ADR-0003, ADR-0006, ADR-0007, ADR-0010, ADR-0011
- **Services live under `GameRoot/Services` and are injected; none is an autoload** (`SettingsService`, `SaveService`, `UiService`, `FlashGate`, `PresentationDirector`). `ContentCatalog` remains the one autoload — source: ADR-0002, ADR-0008, ADR-0009, ADR-0001
- **All player-visible text is English source text through `tr(source, context)`, scene auto-translation or `LocText`** — in every layer — source: ADR-0013
- **No file under `user://` is ever loaded as a `Resource` or decoded by Godot's variant parser** — in every layer — source: ADR-0009
- **Core-layer code never imports Feature-layer types.** `DioramaStage` and `CharacterSprite` (Core) never reference `BattleReplayController` (Feature); Feature consumes Core only through injected `Callable`s and signals — source: ADR-0005 §3 step "Core never imports Feature", ADR-0006
