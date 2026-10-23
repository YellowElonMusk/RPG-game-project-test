# ADR-0004: Content Boot Ordering — Registration Before Validation

## Status
Accepted — amended by ADR-0013 (§1's registrant list gains the `LocFieldsValidator` registration, for every record type; Accepted 2026-10-22, amendment in effect, annotation only) and ADR-0011 (§1 step 2: `ContentBootstrap.run()` builds the `FactionRuleRegistry`, registers its record validators and returns it in its boot result for `GameRoot`, the same return path as `PresentationConfig`; Accepted 2026-10-22, amendment in effect, annotation only)

## Date
2026-10-21

## Last Verified
2026-10-23

## Decision Makers
User (autonomous mode — decisions logged in `production/session-logs/decision-log.md`), Claude (orchestrating session). Split out of ADR-0003 at the request of the technical-director (TD-ADR finding 1); reviewed by godot-specialist and technical-director

## Summary
ADR-0001 runs `ContentCatalog.load_all()` in the catalog autoload's own `_ready()`, but also requires Feature-layer systems to register their vocabularies *before* validation runs. Nothing can register that early, so validation would always run with no vocabularies. Decided: a composition-root `ContentBootstrap.run(catalog)` performs every registration, including a new `register_record_validator()` hook, and then calls `load_all()` exactly once. `GameRoot` calls it in `_enter_tree()`; harness scenes and the headless CI validator call the same function.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core |
| **Layer** | Foundation (the catalog contract: load entry point and validator hook). `ContentBootstrap` itself is composition-root code, not a Foundation module |
| **Knowledge Risk** | LOW for the APIs used, but the decision depends on node lifecycle order. That order is NOT SOURCEABLE in `docs/engine-reference/godot/**`, so it was **measured on 4.7.2** (below) instead of assumed. Measuring corrected a premise that ADR-0001 also states: an autoload's `_ready()` does **not** run before the main scene's `_enter_tree()`. Only autoload `_init()`/`_enter_tree()` do. The project is on 4.7.2, which is post-cutoff overall (HIGH), but no post-cutoff API is used |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` (no Core module exists) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | **Verified on 4.7.2.stable, headless, 2026-10-21** (godot-specialist spike in the session scratchpad: an autoload, a main-scene root with nested children, 3 `.tres` records). **Game run:** autoload `_init` → autoload `_enter_tree` → main root `_enter_tree` (where the bootstrap ran and loaded 3 records to READY) → a child added during it gets `_enter_tree` → the `.tscn` children's `_enter_tree` → **autoload `_ready`** → children's `_ready` (deepest first) → root `_ready`. Every child saw READY in both `_enter_tree` and `_ready`. **Under `-s` (a `SceneTree` script):** the autoload is not reachable in `_init()` but is in `_initialize()`, and the autoload's `_ready` ran *after* `_initialize()` returned. Also verified: `get_global_class_list()` works from `_enter_tree()` and from `-s` (it needs the `.godot/` class cache, so a fresh checkout runs `--import` first); a `class_name`-only script is implicitly `RefCounted`; a static function passed as a `Callable` reports `is_valid()` and works with `call`/`callv`; a second `run()` was a no-op; a registered validator's error failed the load. **Still to do:** port these checks into the regression tests in Migration Step 1 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Content Data Definitions storage format) — **Accepted**: the catalog, its states, and `register_known_effect_types`. ADR-0002 (Game State & Scene Flow) — **Accepted** 2026-10-22: `GameRoot` as the composition root and Boot as the consumer of the catalog's terminal state. ADR-0004 cannot be Accepted before ADR-0002 |
| **Enables** | ADR-0003 (Input System) — its bindings validator registers through `register_record_validator()`; Turn Battle System and Faction Rule Modifiers vocabulary registration (ADR-0001's design, now with a place to run); `res://tools/ci/validate-content.gd` validating with full vocabularies |
| **Blocks** | ContentCatalog implementation (ADR-0001's migration Steps 1+) — the load entry point must be built this way from the start; ADR-0003's acceptance |
| **Ordering Note** | **Amends ADR-0001 and ADR-0002 additively.** The original text is annotated, not rewritten, and each amendment takes effect when ADR-0004 is Accepted.<br>**ADR-0001**, four passages: (a) the "Access pattern" paragraph's reason (3) and its closing sentences ("the autoload's own `_ready()` is the bootstrap"); (b) the Implementation Guideline saying "`ContentCatalog`'s `_ready()` load pass always sees registered record classes", since there is no longer a `_ready()` load pass; (c) Migration Step 1's "as the autoload described in Decision", for the load entry point only; (d) Key Interfaces, which gains `register_record_validator()`. The autoload stays the access pattern for read-only lookups.<br>**ADR-0002**, two passages: Decision §10's "the autoload has already run `load_all()` in its `_ready()`" becomes "`GameRoot._enter_tree()` has already run `ContentBootstrap.run()`"; and Decision §2's `GameRoot` description gains that `_enter_tree()` call. The machine is still built in `GameRoot._ready()` per its §9.<br>`ContentCatalog` is not implemented yet, so no shipped code changes |

## Context

### Problem Statement
ADR-0001 contains two requirements that cannot both hold (and the first rests on a lifecycle premise that measurement on 4.7.2 contradicts: an autoload's `_ready()` actually runs *after* the main scene's `_enter_tree()` pass; see Engine Compatibility):
- *Access pattern* reason (3): "Godot autoloads are guaranteed to run their `_ready()` before the main scene's, so `ContentCatalog.load_all()` runs at `_ready()`".
- *Vocabulary ownership*: "owning systems register their known vocabulary with the catalog before validation runs".

The registrants (Turn Battle's effect types, Faction Rule Modifiers' rule classes, and now ADR-0003's bindings validator) are Feature-layer or Input code that only runs once a scene exists, which is after the autoload's `_ready()`. So validation would always run with empty vocabularies and reject every EffectDescriptor. The same gap breaks ADR-0001's headless `validate-content.gd`. ADR-0001 anticipated this when it scoped the autoload bootstrap "until Game State & Scene Flow exists". ADR-0002 now provides Game State, so the bootstrap can move.

### Constraints
- ADR-0001's `ContentCatalog` remains a read-only-after-Ready autoload (registry `content_catalog_access`); this ADR changes *when it loads*, not how it is accessed.
- ADR-0001: a second `load_all()` in a session is rejected (programmer error). Validation must cover the whole set before reporting, never failing fast.
- ADR-0001: `class_name` registration happens before autoloads run; `load_all()` must not be called from another autoload's `_init()`.
- ADR-0002: Boot must see a terminal `READY`/`FAILED` on its first tick, and `GameRoot` is the composition root; no mutable autoloads.
- Layering: `src/data/` is Foundation and must not import Feature-layer code.

### Requirements
- Every vocabulary and validator is registered before the Validating phase, in the game, in harness scenes and in CI.
- Exactly one `load_all()` per session, whoever calls the bootstrap first.
- A per-record-type validation hook, so a system that owns a record type's *meaning* (Input for `bindings_`) can add semantic checks that fail the catalog like any other content error.

## Decision

**1. `ContentBootstrap` is composition-root code, not Foundation code.** `src/boot/content_bootstrap.gd`:

```gdscript
class_name ContentBootstrap
static func run(catalog: ContentCatalogService) -> void
```

The catalog's script carries `class_name ContentCatalogService`, which differs from its autoload node name `ContentCatalog` so the two never clash. `run()` is typed against it, so the guard's `ContentCatalogService.State.UNLOADED` resolves statically.

`run()` does nothing unless `catalog.state == UNLOADED` (idempotency guard). Otherwise, in this order, it:
1. calls Turn Battle System's registration (`register_known_effect_types(&"turn_battle", …)`, per ADR-0001);
2. calls Faction Rule Modifiers' rule-class registration (per ADR-0001);
3. calls every record-type validator registration: ADR-0003's `register_record_validator(&"bindings", InputBindingsValidator.validate)`, and ADR-0007 §7's Stats validators (`StatsConfig.load_or_default()`, then `register_record_validator()` for `character`, `enemy` and `move` with `StatsValidators.*.bind(config)`);
4. calls `catalog.load_all()`.

The registration list is the one place that knows every registrant. That is why it lives under `src/boot/`, beside the composition root, and not in `src/data/`: the Foundation catalog still imports nothing from above it. Adding a registrant means adding a line here, and the ADR that introduces it names that line.

**2. `GameRoot` runs it in `_enter_tree()`, and builds everything else in `_ready()`.** A parent's `_enter_tree()` runs before any child enters the tree or runs `_ready()`, so the load is complete before anything under `GameRoot` initializes. `GameRoot._enter_tree()` calls **only** `ContentBootstrap.run()`. `GameRoot._ready()` then loads `TransitionConfig`/`InputConfig` (ADR-0002 §9, ADR-0003 §4) and builds the `InputResolver` and the `GameStateMachine`. By that point the load has already finished. Nodes under `GameRoot` receive catalog-derived data through `setup()` (ADR-0002's injection pattern) rather than reading the catalog in their own `_ready()`. Lifecycle order is therefore a safety net, not something the design depends on.

**3. The autoload no longer loads, and its `_ready()` must not change state.** All of `ContentCatalog`'s state (its `state` field, record dictionaries and registries) is set up in field initializers or `_init()`, and it starts `UNLOADED`. On 4.7.2 the autoload's `_ready()` runs **after** `GameRoot._enter_tree()` has already loaded the catalog. Under `-s`, it runs after `_initialize()`. So a `_ready()` that resets or allocates catalog state would silently erase a completed load. `ContentCatalog._ready()` therefore does nothing to catalog state, and ideally is not defined at all. A `get_record()` while `UNLOADED` is rejected like any lookup on a non-Ready catalog, with an error naming the missing bootstrap.

**4. `register_record_validator(type: StringName, validator: Callable) -> void`** is added to `ContentCatalog`. `validator(record: Resource) -> Array[Dictionary]` returns structured entries of the GDD's entry shape (`severity`, `field`, `message`, optional `related_locations`; the catalog fills `record_id` and `location`), and an empty array means valid *(amended 2026-10-23 from `PackedStringArray`: tests assert on structured fields, never on wording)*. During the Validating phase, the catalog calls each registered validator once per record of that type, *after* its own generic checks (ID, prefix, unknown fields, references). It adds each entry, with the record's file path as its location, to the full report, never failing fast. A validator must be pure: no side effects, and no lookups beyond the record it is given. A registration made after `load_all()` has started is rejected with an error and has no effect. Validators run in registration order.

**5. Every other entry point uses the same function.**
- Harness scenes (`battle_debug_harness.tscn`, `battle_hud_demo.tscn`, `chapter_flow_demo.tscn` or its ADR-0002 rewrite) call `ContentBootstrap.run(ContentCatalog)` in their own `_enter_tree()`. They do this once their factories read the catalog, which is ADR-0001 migration Step 3. Before that they don't touch the catalog and need nothing.
- `res://tools/ci/validate-content.gd` (a `SceneTree` script) calls `ContentBootstrap.run()` from `_initialize()`, never `_init()`, where the autoload doesn't exist yet. It gets the catalog with `root.get_node(^"ContentCatalog")` and exits with `min(error_count, 1)` (ADR-0001 amendment 2026-10-23), so CI validates with every vocabulary and validator registered. It passes `--data-root=` to `ContentBootstrap.run(data_root)`. A fresh checkout runs `godot --headless --path . --import` first, so the class cache exists.
- Thanks to the guard, a harness that is later embedded under `GameRoot` cannot trigger a second load.

### Architecture Diagram

```
 engine start ─► class_name registration ─► ContentCatalog._init() / _enter_tree()   (state = UNLOADED)
                                                              │
 main scene ─► GameRoot._enter_tree() ─► ContentBootstrap.run(ContentCatalog)
                                           ├─ register_known_effect_types (Turn Battle)
                                           ├─ faction rule-class registration
                                           ├─ register_record_validator(&"bindings", …)  (ADR-0003)
                                           ├─ register_record_validator(character/enemy/move, StatsValidators…)  (ADR-0007)
                                           └─ load_all() ─► LOADING ─► VALIDATING ─► READY | FAILED
               ─► GameRoot builds InputResolver, GameStateMachine
               ─► children _enter_tree
               ─► ContentCatalog._ready()       ← runs HERE (verified 4.7.2): must not touch state
               ─► children _ready (deepest first) ─► GameRoot._ready
               ─► first tick: Boot reads terminal state ─► Title | Content Error   (ADR-0002)

 harness scene._enter_tree() ─► ContentBootstrap.run(ContentCatalog)   (no-op if not UNLOADED)
 validate-content.gd._initialize() ─► run(root.get_node(^"ContentCatalog")) ─► exit(error_count)
                                       (autoload _ready runs after _initialize returns)
```

### Key Interfaces

```gdscript
## src/boot/content_bootstrap.gd — composition root; the only file listing every registrant
class_name ContentBootstrap
static func run(catalog: ContentCatalogService) -> void   # no-op unless state == ContentCatalogService.State.UNLOADED

## Additions to ContentCatalog (ADR-0001)
func register_record_validator(type: StringName, validator: Callable) -> void
#   validator: func(record: Resource) -> Array[Dictionary]   (pure; structured entries; empty = valid; amended 2026-10-23)
#   rejected (error, no effect) once load_all() has started
```

### Implementation Guidelines
- `ContentCatalog.load_all()` must be called only by `ContentBootstrap.run()`. The autoload's `_ready()`, other autoloads, modes, overlays and tests other than the catalog's own unit tests must never call it.
- `ContentBootstrap.run()` must return without effect unless the catalog is `UNLOADED`.
- `ContentCatalog` must set up all its state in field initializers or `_init()`. Its `_ready()` must not assign, clear or allocate any catalog state, because it runs after the bootstrap has loaded.
- `validate-content.gd` must call `run()` from `_initialize()`, never `_init()`.
- The catalog script must declare `class_name ContentCatalogService`, and `run()` must be typed against it.
- `GameRoot._enter_tree()` must call `ContentBootstrap.run()` and nothing else. `InputResolver`, `GameStateMachine` and the config resources are built in `GameRoot._ready()`.
- Only `game_root.gd`, harness scenes and `validate-content.gd` may reference `src/boot/`. `game_state_machine.gd`, `src/data/` and every Feature-layer script must not.
- Nodes under `GameRoot` must get catalog data through `setup()`, not by reading the catalog in `_ready()`.
- `src/data/` must not import `src/boot/` or any Feature-layer script; registrants are wired only in `ContentBootstrap`.
- Record validators must be pure and must report every error for their record, never stopping at the first one.
- An ADR that adds a registrant must name its line in `ContentBootstrap.run()`.

## Alternatives Considered

### Alternative 1: Keep the autoload load; register from static initializers
- **Description**: Each registrant class registers itself in a static variable initializer or a static method that the catalog triggers before validating.
- **Pros**: No bootstrap file; the autoload still "just loads".
- **Cons**: GDScript static initializers run only when the class is first referenced, so the catalog would have to reference every Feature-layer class to trigger them. That is the upward dependency ADR-0001 explicitly rejected. Ordering would be invisible.
- **Rejection Reason**: Reintroduces Foundation → Feature coupling, or doesn't run at all.

### Alternative 2: Lazy load on the first lookup
- **Description**: `get_record()` triggers `load_all()` the first time it is called.
- **Pros**: No explicit boot step.
- **Cons**: Registration still has to happen before the first lookup, which could come from anywhere. Boot can't wait on a load that hasn't started. The load cost lands at an unpredictable moment, possibly mid-transition, against ADR-0002's budgets. And Content Error can't be reached deterministically.
- **Rejection Reason**: Hides ordering instead of fixing it.

### Alternative 3: Keep it inside ADR-0003 (Input System)
- **Rejection Reason**: Boot ordering governs every registrant and changes ADR-0001's rationale; it is not an Input decision (TD-ADR finding on ADR-0003).

## Consequences

### Positive
- ADR-0001's vocabulary-ownership design becomes executable: every registrant runs before validation, in the game, in harnesses and in CI.
- Exactly one load per session by construction, whichever entry point runs first.
- Record-type owners (Input today; Dialogue, Overworld later) can add semantic validation that fails the catalog through Content Data's own rule-8 path.
- The Foundation catalog still imports nothing from above it.

### Negative
- The "any scene's `_ready()` can call `get_record()`" convenience from ADR-0001 reason (3) is gone. A scene not under `GameRoot` must run the bootstrap itself.
- `ContentBootstrap` is a central list every registrant ADR must edit.
- An Accepted ADR (ADR-0001) carries an amendment from a later ADR, so readers must follow its Status and Review History.

## Risks
- **Someone adds state initialization to `ContentCatalog._ready()`**, which runs after the load and would silently erase it. *Mitigation*: Implementation Guidelines, plus a regression test asserting that the catalog is still READY with its records intact after its own `_ready()` (Validation Criteria).
- **A harness scene forgets to call the bootstrap** and every lookup fails with an UNLOADED error. *Mitigation*: the error names the missing bootstrap; the failure is immediate and loud, never silent.
- **A child under `GameRoot` reads the catalog in `_ready()` anyway.** *Mitigation*: the load is already finished by then because of `_enter_tree()` ordering (Verification item 1); the `setup()` rule is a design rule, not the only guard.
- **A slow load blocks the first frame**, since `_enter_tree()` is synchronous. *Mitigation*: Content Data's own `LOAD_TIME_BUDGET` (1.0 s) bounds it, and Boot exists to cover exactly this moment.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| content-data-definitions.md | Interactions: Game State "starts the load at boot; blocks until Ready" | `GameRoot` (Game State's composition root) starts the load in `_enter_tree()`; Boot reads the terminal state |
| content-data-definitions.md | Rule 8 — validate the complete set and report every problem; CI-runnable headless validation | Validators run inside the full-set pass; `validate-content.gd` uses the same bootstrap with all registrants |
| game-state-scene-flow.md | Rule 13 / TR-gamestate-005 — Boot waits for the catalog: Ready → Title, Failed → Content Error | Load completes before the machine exists, so Boot's first tick sees a terminal state |
| input-system.md | Rule 7 / Edge Cases — invalid bindings are a content error and the game does not start | `register_record_validator(&"bindings", …)` fails the catalog |

## Performance Implications
- **CPU**: None at runtime beyond the existing load and validation. Validators add a per-record call during Validating.
- **Memory**: None.
- **Load Time**: Unchanged total. The load moves from the autoload's `_ready()` to `GameRoot._enter_tree()`, still before the first rendered frame of the main scene.
- **Network**: None.

## Migration Plan
`ContentCatalog` is not implemented yet, so this is the first implementation shape, not a migration:
0. Registry, on writing this ADR:
   - `content_vocabulary_registration`: producer becomes "invoked via `ContentBootstrap.run()`", and ADR-0004 is added;
   - `content_catalog_access`: ADR-0004 is added;
   - a new `content_record_validation` contract (`register_record_validator`);
   - a new forbidden pattern, `load_all()` outside `ContentBootstrap`.
1. When ADR-0001's catalog is built: no `load_all()` in `_ready()`; add `register_record_validator()`; add `src/boot/content_bootstrap.gd` with the guard. Add a lifecycle regression test (Verification item 1) and an idempotency test (a second `run()` is a no-op).
2. `validate-content.gd` calls `ContentBootstrap.run()`.
3. With ADR-0002's `GameRoot` story: call `run()` in `GameRoot._enter_tree()`.
4. With ADR-0001 migration Step 3, when the factories read the catalog: add `ContentBootstrap.run(ContentCatalog)` to `_enter_tree()` in `battle_debug_harness`, `battle_hud_demo` and `chapter_flow_demo` (or its ADR-0002 rewrite).

## Validation Criteria
- A unit test: registering a validator for a type and feeding one bad record yields exactly that validator's errors in the catalog's list, plus `FAILED`. A validator registered after `load_all()` starts is rejected.
- A unit test: `ContentBootstrap.run()` twice causes exactly one `load_all()`.
- A lifecycle test: a child of a `GameRoot` stand-in sees a terminal catalog state in its own `_ready()`, and after the catalog autoload's own `_ready()` has run, the catalog is still `READY` with every record present.
- `validate-content.gd` on a clean data set exits 0. With an EffectDescriptor whose type is valid only once Turn Battle has registered, it still exits 0, which proves registration ran.
- Code review finds no `load_all()` call outside `ContentBootstrap`, and no `src/data/` import of `src/boot/` or Feature code.

## Related
- Amends:
  - `docs/architecture/adr-0001-content-data-storage-format.md`: Access pattern reason 3 and the bootstrap sentence; the Implementation Guideline on "`_ready()` load pass"; Migration Step 1's load entry point; Key Interfaces gains `register_record_validator`.
  - `docs/architecture/adr-0002-game-state-scene-flow.md`: Decision §2 (`GameRoot._enter_tree()`) and §10.

## Review History
- 2026-10-21 — **godot-specialist** (engine validation): BLOCKING on one premise, now revised. On 4.7.2 an autoload's `_ready()` runs after the main scene's `_enter_tree()`, and under `-s` after `_initialize()`. The rest was verified empirically (Engine Compatibility).
- 2026-10-21 — **technical-director** (TD-ADR): CONCERNS, 5 text fixes, all applied: the full ADR-0001 amendment scope (4 passages, annotated, not rewritten); `_enter_tree()` runs only the bootstrap and everything else is built in `_ready()` (ADR-0002 §2/§9 consistency); the Layer field and the `src/boot/` reference rule; a registry Migration Step 0; `ContentCatalogService` typing made mandatory. TD confirmed the ADR-0003 split is clean.
- 2026-10-22 — `/architecture-review` (`architecture-review-2026-10-22.md`): nothing blocking for this ADR (godot-specialist: accept with or after ADR-0002).
- 2026-10-22 — **Accepted** by the user, after ADR-0002 (explicit instruction: accept ADR-0002 → ADR-0004 → ADR-0003 → ADR-0006 → ADR-0005). The annotated amendments to ADR-0001 (four passages) and ADR-0002 (§2, §10) take effect now. No stories were Blocked on this ADR.
- Enables: `docs/architecture/adr-0003-input-system.md` (bindings validator)
- Design: `design/gdd/content-data-definitions.md`, `design/gdd/game-state-scene-flow.md`, `design/gdd/input-system.md`

- 2026-10-23 — Path correction (no decision change): the headless validator lives at `res://tools/ci/validate-content.gd`, not `res://.claude/scripts/`. `.claude/` holds the agent framework's helpers, while game tooling belongs under `tools/ci/` (`.claude/docs/directory-structure.md`), next to ADR-0012's `tools/ci/validate_maps.gd`. Control manifest updated to match. Found while drafting the content-catalog stories.
- 2026-10-23 — Testability amendment (no decision change; QL-STORY-READY on the content-catalog stories): lookup error channel `last_lookup_error`, `load_all(data_root) -> Error`, headless exit `min(error_count, 1)` with `--data-root=`, `duplicate_deep()` copies (ADR-0001); record validators return structured `Array[Dictionary]` entries instead of `PackedStringArray` (ADR-0004 §4; ADR-0003, ADR-0007 and ADR-0011 signatures and the control manifest synced).
