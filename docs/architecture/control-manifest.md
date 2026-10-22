# Control Manifest

> **Engine**: Godot 4.7.2 (GDScript)
> **Last Updated**: 2026-10-21
> **Manifest Version**: 2026-10-21
> **ADRs Covered**: ADR-0001
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Stories embed it when
they are written, and `/story-readiness` compares a story's version with this one
to find stories written against old rules. It always equals `Last Updated`: the
same date, for different readers.

This manifest is a programmer's quick reference taken from the Accepted ADRs, the
technical preferences and the engine reference docs. For the reason behind a rule,
read its ADR.

**Coverage today:** one Accepted ADR (ADR-0001, Foundation). The Core, Feature and
Presentation layers have no Accepted ADR yet, so they carry only the global rules.
`docs/architecture/architecture.md` § Required ADRs lists the decisions still owed
(Game State & Scene Flow, Input System and Sprite & Camera Presentation must be
Accepted before any code that depends on them).

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine start-up, and the
Content Data Definitions catalog (`ContentCatalog`)*

### Required Patterns

**Record types and files**
- **Every content record type is its own `Resource` subclass** (`class_name`, `extends Resource`) with every scalar and enum field as a typed `@export` var — source: ADR-0001
- **EffectDescriptors (`effects` fields) are stored as plain `Array[Dictionary]`** (`{type, ...params}`), the one non-scalar export — source: ADR-0001 (GDD Requirements, Rule 4 row)
- **Every record exports `id: String`**, and `aliases: PackedStringArray` where ID aliasing applies — source: ADR-0001
- **One record = one `.tres` file at `data/[type_plural]/[id].tres`** (e.g. `data/characters/char_baguette_thrower.tres`); the filename without extension must equal the record's `id`, and the validation pass checks it — source: ADR-0001
- **Cross-references are `String` / `PackedStringArray` fields holding record IDs** (`nation_id`, `move_ids`, `faction_id`, …) — source: ADR-0001
- **Record scripts live at a stable path (`src/data/records/`) and are not renamed casually**: every `.tres` references its script by path — source: ADR-0001

**Loading and access**
- **`ContentCatalog` is an autoload singleton**, registered under `[autoload]` in `project.godot`; it calls `load_all()` from its own `_ready()`. This is the one documented exception to "dependency injection over singletons" — source: ADR-0001
- **Discover files with `ResourceLoader.list_directory(path)`**, recursed per subdirectory under `data/` — source: ADR-0001
- **Lookup API names are `get_record(type, id)`, `has_record(type, id)`, `all_records(type)` (sorted by `id`) and `resolve_alias(id)`**; state is `ContentCatalog.state` (`UNLOADED | LOADING | VALIDATING | READY | FAILED`) — source: ADR-0001
- **The catalog loads once per session; `READY` is terminal.** A second `load_all()` is rejected — source: ADR-0001
- **Consumers copy a record's values into their own runtime objects** (`Combatant`, `Move`) at construction time; records are shared, cached `Resource` instances — source: ADR-0001
- **Static factories become adapters**: they read the catalog record and build today's runtime `Move` / `Combatant` objects. `BattleCore` never touches a catalog record — source: ADR-0001
- **Attack and Defend stay code-side factories** (`Move.make_attack()` / `make_defend()`), not records — source: ADR-0001

**Validation**
- **Validation runs over the complete record set before reporting**, every problem collected — source: ADR-0001
- **The validation pass covers**: ID format and uniqueness, filename = `id`, reference resolution, cycle detection, numeric ranges, unknown fields, parse failures and Resource-typed exports — source: ADR-0001 (Decision, Consequences)
- **Each error class has a deliberately malformed `.tres` fixture** that must produce its named validation error, not a crash or silent skip: bad/duplicate ID, dangling reference, unknown EffectDescriptor `type`, unknown (typo'd) field, unparsable file — source: ADR-0001 (Validation Criteria)
- **Unknown fields are detected by reading each `.tres` file's raw text (`FileAccess`)**, parsing the `[resource]` section's `key = value` lines, and diffing against the instance's `get_property_list()` (storage/script properties) — source: ADR-0001
- **Every required field has an enforced validity rule** (non-empty text, numeric range from the owning GDD), which is how "missing" is detected — source: ADR-0001
- **Check `ResourceLoader.load(path)` for `null`**, record a validation error naming the file, and keep loading the rest — source: ADR-0001
- **Validation rejects any record script that declares an Object/Resource-typed export** (inspected through the script's property list) — source: ADR-0001
- **Owning systems register their vocabulary before validation**: Turn Battle System calls `ContentCatalog.register_known_effect_types(system, types)` before the Validating phase; Faction Rule Modifiers resolves `rule_id` to its own rule classes via `ProjectSettings.get_global_class_list()` — source: ADR-0001
  - ⚠️ **ADR-0001 open item — resolve before implementing the catalog.** As written, `load_all()` runs from `ContentCatalog`'s own `_ready()`, and no Turn Battle System code runs before that, so registration cannot happen first. An ADR-0001 amendment must choose either (a) register from an autoload listed *before* `ContentCatalog`, or (b) the Validating phase waits until registration is done. Raised by TD-MANIFEST 2026-10-21.
- **Numeric ranges (e.g. `max_hp` 1–999) are read from a constants reference owned by Stats & Damage Resolution**, not written as literals in `ContentCatalog` — source: ADR-0001
- **Headless validation script at `res://.claude/scripts/validate-content.gd`**, exiting with the error count, run as `godot --headless -s res://.claude/scripts/validate-content.gd` — source: ADR-0001

**Migration**
- **Characterization tests are written against today's hardcoded factories before migration** and rerun unchanged after it; they do not use the catalog — source: ADR-0001
- **Run each verification or characterization pass in a fresh engine process**: `ResourceLoader.load()` defaults to `CACHE_MODE_REUSE`, so `.tres` edits made within one process are not picked up — source: ADR-0001 (Risks)
- **Enemy AI keys behaviour off the record `id`, never `display_name`** (MegaCorp's AI currently checks `display_name == "Middle Manager"`; migration must switch it to the ID) — source: ADR-0001 (Risks, Migration Plan step 2)
- **The five migrated EffectDescriptor types are `stun`, `heal_party`, `heal_single`, `damage_debuff`, `direct_damage`**, provisional until the Quirk State System is designed; migrate stable data (enemy stat blocks, faction tuning, faction records) before them — source: ADR-0001

### Forbidden Approaches
- **Never use `@export var x: OtherResourceType` for a cross-reference** — it breaks ID-only references (GDD Rule 3) and couples records by file path through `ExtResource` — source: ADR-0001
- **Never put logic in a record class** beyond basic getters; no record script computes a gameplay effect (GDD Rule 4) — source: ADR-0001
- **Never mutate a record's fields after load**, and never use a record as live runtime state — it is a cached instance shared by every caller — source: ADR-0001
- **Never name lookups `get()`, `exists()` or `all()`** — `get` collides with `Object.get(property)` — source: ADR-0001
- **Never enumerate content files with `DirAccess`** — exported builds expose `.remap` companions instead of `.tres` names — source: ADR-0001
- **Never fail fast on the first bad record** — source: ADR-0001
- **Never call `load_all()` from another autoload's `_init()`** — it can run before `class_name` registration — source: ADR-0001
- **Never rely on `Resource` loading alone to catch unknown or missing fields** — Godot silently drops unknown properties and fills defaults — source: ADR-0001
- **Never resolve Feature-layer vocabularies inside `ContentCatalog`** (effect types, faction rule classes) — the Foundation layer must not depend upward — source: ADR-0001
- **Never treat `.godot/imported/` as content** — `.tres` files are the source of truth — source: ADR-0001
- **Never store content as plain JSON files or `ConfigFile` sections** — rejected for lack of typing and Inspector authoring (JSON) and for no nested structures (`ConfigFile`) — source: ADR-0001

### Performance Guardrails
- **ContentCatalog**: loads once at boot, never per frame; every record stays resident for the session — source: ADR-0001
- **ContentCatalog load + validation**: file reading plus validation, excluding engine startup, median of 10 runs on 500 generated records under 1.0 s, on the development PC (provisional until target hardware is decided). Run as a benchmark, not a unit test; `LOAD_TIME_BUDGET` and `BENCHMARK_RECORD_COUNT` live in benchmark config, not code — source: `design/gdd/content-data-definitions.md` F5 / AC-25 (GDD budget; ADR-0001 calls load time negligible and sets no number)

### Engine Verification Required
- **`ResourceLoader.list_directory()` (added 4.4, post-cutoff)**: verified in the editor on 4.7.2; **re-verify against an exported build before the first real content migration ships** — source: ADR-0001

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems, physics, collision*

No Accepted ADR governs this layer yet. Global rules apply.

---

## Feature Layer Rules

*Applies to: secondary mechanics, AI systems, secondary features*

### Required Patterns
- **Turn Battle System registers its EffectDescriptor types with `ContentCatalog` before validation; Faction Rule Modifiers owns `rule_id` → rule class resolution** — source: ADR-0001 (the Feature-layer side of the Foundation vocabulary rule)

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, animations*

No Accepted ADR governs this layer yet. Global rules apply.

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
| Draw calls | 2000 | `performance.draw_call_limit` in project.yaml |
| Memory ceiling | not configured | `.claude/docs/technical-preferences.md` (`[TO BE CONFIGURED]`) |

### Approved Libraries / Addons
- None configured yet — source: technical-preferences.md. (gdUnit4 is the test framework named in `.claude/docs/coding-standards.md` CI rules; install it from the editor's Asset Store workspace — source: `current-best-practices.md` § Editor Workflow 4.7.)

### Forbidden Patterns
- None configured yet — source: technical-preferences.md

### Forbidden APIs (Godot 4.7.2)
These are deprecated or renamed in the pinned version. Use the replacement. 3D-only
entries are left out because this is a 2D project.
- `TileMap` → `TileMapLayer` (4.3)
- `VisibilityNotifier2D` → `VisibleOnScreenNotifier2D` (4.0)
- `YSort` → `Node2D.y_sort_enabled` (4.0)
- `Navigation2D` → `NavigationServer2D` (4.0)
- `yield()` → `await signal` (4.0)
- `connect("signal", obj, "method")` / string-based `connect()` → `signal.connect(callable)` (4.0)
- `instance()` / `PackedScene.instance()` → `instantiate()` (4.0)
- `OS.get_ticks_msec()` → `Time.get_ticks_msec()` (4.0)
- `duplicate()` for nested resources → `duplicate_deep()` (4.5)
- `AnimationPlayer.method_call_mode` → `AnimationMixer.callback_mode_method`; `AnimationPlayer.playback_active` → `AnimationMixer.active` (4.3)
- `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` → `UPDATE_WIDTH_UNIT`; `add_image()` / `update_image()` `width_in_percent` / `height_in_percent` → `width_unit` / `height_unit` (`RichTextLabel.ImageUnit`) (4.7)
- `DisplayServer.AccessibilityLiveMode` → `AccessibilityServer.AccessibilityLiveMode` for `Control.accessibility_live` (4.7)
- `AudioEffectSpectrumAnalyzer.tap_back_pos` — removed (4.7)
- `event.device == 0` to detect mouse/keyboard → `event is InputEventMouse` / `InputEventKey`, or `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` (4.7)
- `$NodePath` inside `_process()` → an `@onready var` cached reference
- Untyped `Array` / `Dictionary` → `Array[Type]` and typed variables
- When writing shaders: `Texture2D` in `Shader.set_default_texture_parameter()` / `get_default_texture_parameter()` → `Texture` (4.4)
- Source: `docs/engine-reference/godot/deprecated-apis.md`

### Required Engine Patterns (Godot 4.5–4.7)
- **An override of a typed method needs an explicit `return`** (it inherits the return type in 4.7) — source: `current-best-practices.md` § GDScript (4.7)
- **Assign a whole packed array when its property setter must run**; `arr[i] = v` no longer calls the setter (4.7) — source: `current-best-practices.md` § GDScript (4.7)
- **Lambdas capture locals by value**: share state through a Dictionary, Array or object — source: `current-best-practices.md` § GDScript (4.5+)
- **UI focus is dual (4.6)**: mouse/touch focus is separate from keyboard/gamepad focus; account for it in custom focus behaviour — source: `current-best-practices.md` § UI (4.6)
- **`CanvasItem` lines have no antialiasing feather in 4.7**; widen lines that relied on the old look — source: `current-best-practices.md` § Rendering (4.7)
- **Search GDScript with `glob: "*.gd"`**, never `rg --type gdscript` (it does not exist) — source: `current-best-practices.md` § Tooling
- **Parse-check scripts with `res://.claude/scripts/godot-parse-check.gd`**, not `--check-only` (fails on autoload names) or `--import` (exits 0 on parse errors) — source: `current-best-practices.md` § Command Line

### Cross-Cutting Constraints
- **Gameplay values are data-driven, never hardcoded**; with ADR-0001 the data lives in `ContentCatalog` records — source: `.claude/docs/coding-standards.md`, ADR-0001
- **Dependency injection over singletons**, with `ContentCatalog` as the one documented exception — source: `.claude/docs/coding-standards.md`, ADR-0001
- **Doc comments on every public API** — source: `.claude/docs/coding-standards.md`
