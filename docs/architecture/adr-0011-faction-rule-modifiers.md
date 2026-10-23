# ADR-0011: Faction Rule Modifiers — Stateless Rule Objects, an Explicit Rule Registry, Rule Parameters and Text as Data

## Status
Accepted

## Date
2026-10-22

## Last Verified
2026-10-22

## Decision Makers
User (autonomous mode — decisions logged in `production/session-logs/decision-log.md`; GDD Open Question 1 answered "Option A" autonomously, pending user veto), Claude (orchestrating session), reviewed by godot-specialist (engine validation, probed on 4.7.2) and technical-director (TD-ADR). Retroactive: `FactionRule`, `BureaucratiaRule` and `MegaCorpRule` ship in `src/battle/factions/` (MVP Stories 002 and 004). Revision 2 folds in both reviews.

## Summary
Each alien faction bends the battle's rules through a `FactionRule` subclass that `BattleCore` and the HUD consult without ever branching on which faction it is (TR-factionrules-001). The contract grew by addition across three stories and was never decided. ADR-0001 deferred the `Faction.rule_id` → class mapping to this system (TR-factionrules-002). ADR-0007 adds a tenth hook, and ADR-0010 needs a typed enemy-action result. Every rule's tuning, its colours and its banner text are still code, and MegaCorp's AI tells enemies apart by display name.

Decided:
- `FactionRule` stays one instantiable base class, with neutral defaults and no per-battle state.
- A `FactionRuleRegistry`, built by `ContentBootstrap` and handed to `BattleFactory`, maps a rule class ID to a factory and a parameter validator.
- The reserved `FactionRule` record type becomes concrete. It names a registered rule class and carries:
  - that class's parameters;
  - its player-visible text templates;
  - its presentation colours;
  - a list of the records it references, which the catalog's generic reference pass resolves.
- Validators stay pure.
- `Combatant` gains a `record_id`, so a rule tells enemies apart by record, not by name.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scripting: `RefCounted` subclasses, `Callable`, `Resource` records) |
| **Layer** | Feature |
| **Knowledge Risk** | LOW. The only post-cutoff API is 4.7's inherited typed return on overrides |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (the 4.7 typed-return override row), `deprecated-apis.md`, `current-best-practices.md` |
| **Post-Cutoff APIs Used** | 4.7: an override of a typed method inherits its return type. A non-void override missing a `return` on some path is a **hard parse error that fails every dependent script** (probed), not a warning |
| **Verification Required** | **Probed on 4.7.2 (godot-specialist, 2026-10-22):**<br>(1) A `Callable` to a constructor or to a static `from_data`, stored in a `Dictionary[StringName, Callable]` and called later, returns a fresh instance of the right subclass. **PROBED.**<br>(2) A `Resource` with `@export var params: Dictionary` round-trips through `.tres` with `int`, `float`, `String` and `bool` types intact, with no int→float promotion. `@export var rule_class: StringName` round-trips as `StringName`. **PROBED.**<br>(3) `Array[EnemyAction]` returned from an override keeps its element type at the call site. An override returning an empty untyped `[]` is coerced to the declared type. **PROBED.** A non-empty literal with wrong-typed elements is expected to be a runtime type error. **REASONED.**<br>Note: a fresh checkout must run `--import` before `class_name` lookups resolve under `--script`. **PROBED** |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001** (Content Data, **Accepted**): `Faction.rule_id`, the reserved `FactionRule` record type, data-only records, the generic reference pass (Rule 8), `Enemy`/`Move` records.<br>**ADR-0004** (Content Boot Ordering, **Accepted**): `ContentBootstrap.run()` step 2, `register_record_validator()` and its purity rule (§4).<br>**ADR-0007** (Stats & Damage, **Accepted**): `register_resolution_hooks(hooks)`, `Combatant` as a Core type, and MP left outside the resolver.<br>**ADR-0013** (Localization, **Accepted**): `FactionRuleData.texts` listed in `LOC_FIELDS`, read through `LocText`; the fallback rule's sentences through `tr(source, context)` |
| **Enables** | **ADR-0010** (Turn Battle System), which consumes `EnemyAction`, `FactionRuleRegistry` and `Combatant.record_id`. **ADR-0010 depends on this ADR.**<br>**ADR-0001 Migration Step 3 for factions:** rule records, rosters as `Enemy` records, named attacks as `Move` records.<br>**New factions** (Influencia, Liberty-7): content plus, at most, one new rule class each |
| **Blocks** | ADR-0010's acceptance; any story adding a faction or changing a rule's tuning; ADR-0001's faction record migration |
| **Ordering Note** | **Additive amendments (annotation only):**<br>- **ADR-0001:** `rule_id` resolution no longer uses `ProjectSettings.get_global_class_list()` (§4). The reserved `FactionRule` record type is defined (§5). `Faction.rule_id` is an ordinary reference to a `faction_rule` record, checked by the generic reference pass.<br>- **ADR-0004 §1 step 2:** `ContentBootstrap.run()` builds the `FactionRuleRegistry`, registers its record validators, and returns it in its boot result for `GameRoot` to pass on. This is the same return path ADR-0005 uses for `PresentationConfig`.<br>- **ADR-0007 §0:** `Combatant` gains the immutable `record_id: String`, set at construction. It is identity, not a stat, and the resolver never reads it.<br>**Ordering:** accept this ADR before ADR-0010 |

## Context

### Problem Statement
`FactionRule` is the seam that keeps `BattleCore` faction-agnostic, and the MVP proves it works. The battle HUD renders both factions through one code path, and `BattleCore` has no faction branch. But the seam was never designed:

- **The contract grew by addition.** Rules, enemy AI, round upkeep, move legality and five presentation getters sit in one class (GDD Open Question 1). ADR-0007 adds `register_resolution_hooks()`.
- **`choose_enemy_action()` returns an untyped `Array` of `Dictionary`.** ADR-0010 needs it typed.
- **The `rule_id` mapping is undecided.** ADR-0001 sketched reflection over `ProjectSettings.get_global_class_list()`, which ties content to script class names.
- **Tuning is code.** `PERMIT_ROUNDS = 3`, `BILL_MP = 1` (changed by direct user instruction), `LOW_HP_THRESHOLD` and the named-attack powers are `const`s. The rosters are static factories on the rule classes.
- **Presentation is code.** Identity colours (`#4a5a8a` neutral, plus each faction's), Bureaucratia's "permit granted" amber `#b07a12`, and full-sentence banner and tooltip text all live in the scripts. Content Data's player fantasy ("Same alien, every screen") and Rule 6 (player-visible text lives in records) both say otherwise.
- **Identity by name.** `megacorp.gd:98` picks a move by comparing `enemy.display_name` to the Middle Manager's name. `specials.gd:129` calls `BureaucratiaRule.is_manager()` from squad code.

Two more factions are planned as content. The contract has to be fixed before they are written.

### Constraints
- **Retroactive.** Both rules work and have been playtested. Their behaviour and the HUD's faction-agnostic path stay.
- **Retry.** ADR-0002 §7 restores a battle from a snapshot and re-runs `start_battle(false)` on the same `BattleCore`. ADR-0007 rebuilds the hook registry on every `start_battle()`. ADR-0010 doesn't restore the RNG.
- **Layering and purity.** The catalog (Foundation) imports no rule class. ADR-0004's bootstrap is the only file that knows every registrant. A record validator may look at no record but the one it is given (ADR-0004 §4).
- **ADR-0007.** Rules never compute or write HP.

### Requirements
- TR-factionrules-001: a stateless contract with neutral defaults. `BattleCore` and the HUD never branch on the subclass.
- TR-factionrules-002: `Faction.rule_id` maps to a `FactionRule` class through a registry owned by Faction Rule Modifiers code, not by the Foundation layer.
- Rule tuning, rosters, named attacks, colours and text are data.
- An unknown or misconfigured rule is a content error at boot, not a runtime surprise.

## Decision

**1. One base class, ten methods.** `FactionRule` (`src/battle/factions/faction_rule.gd`, `RefCounted`) is deliberately **not** `@abstract`: the base is the neutral rule. It keeps the nine shipped methods, gains ADR-0007's tenth, and is configured from data.

| Group | Method | Neutral default (as shipped, unless noted) |
|---|---|---|
| Rules | `specials_allowed(round_number: int) -> bool` | `true` |
| Rules | `move_allowed(actor: Combatant, move: Move) -> bool` | `true` |
| Rules | `apply_round_upkeep(living_squad: Array[Combatant]) -> void` | nothing |
| Rules | `register_resolution_hooks(hooks: ResolutionHooks) -> void` | nothing (**added by ADR-0007**) |
| AI | `choose_enemy_action(enemy, living_squad, round_number, rng) -> Array[EnemyAction]` | one Attack on a random living squad member (return type typed by this ADR) |
| Presentation | `get_banner_text(round_number) -> String` | the record's `texts.banner`; for the record-less fallback, the shipped neutral sentence via `tr("…", &"rule.fallback.banner")` (ADR-0013) |
| Presentation | `get_tooltip_text(round_number) -> String` | the record's `texts.tooltip`; for the fallback, the shipped neutral sentence via `tr("…", &"rule.fallback.tooltip")` |
| Presentation | `get_combatant_tooltip_note(combatant) -> String` | `""` |
| Presentation | `get_identity_color() -> Color` | the `Faction` record's `signature_color`. The record-less fallback returns `Color(0, 0, 0, 0)`, meaning "no identity colour", and the HUD substitutes its theme's neutral token (ADR-0008) |
| Presentation | `get_banner_color(round_number) -> Color` | `get_identity_color()` |

**The presentation group stays in this class** (GDD Open Question 1, Option A; chosen autonomously and logged for user veto):
- It is small.
- It is the reason the HUD needs no faction branch.
- Splitting it would add a second object per battle and give us no new capability.

If a later faction needs presentation that doesn't fit, the split can be added later without breaking anything: a `FactionPresentation` that delegates to the rule by default.

**The record-less fallback.** `FactionRule.new()` with no configuration is `BattleCore`'s default for harnesses and tests (ADR-0010). It is the only rule without a record. A `human_nation` faction never has a `rule_id` (Content Data Rule 8).

**2. Stateless per battle.**
- **Configuration only.** A rule instance holds only **immutable configuration**, set once in `_configure()`: its faction and rule records' values. The same applies to every modifier or override it registers through `register_resolution_hooks()`.
- **Pure functions.** Every method is a function of its arguments. That covers `BattleCore`'s `round_number`, the `Combatant`s it is given (including their `record_id` and `is_boss`), and the `rng` argument.
- **No state.** A rule **must not** keep counters, remembered targets, or any field it writes after `_configure()`.
- **Why that is enough.** The shipped rules already behave this way: no instance fields, `is_manager()` is static, and randomness comes only from `rng`. With ADR-0007 rebuilding hooks on every `start_battle()` and ADR-0010 not restoring the RNG, Retry needs no rule snapshot (ADR-0002 §7).

**What a rule may change.**
- `apply_round_upkeep()` may change **MP only**, through `Combatant.spend_mp()`. `spend_mp()` clamps at 0, and that clamp is how MegaCorp's suspension happens. ADR-0007 §0 explicitly leaves MP drains outside the resolver, and the registry has no MP ownership stance that this conflicts with.
- A rule **must not** write HP (registry `direct_combatant_hp_write`). To change damage or healing, it registers a modifier or override.
- A rule **must not** touch Turn Battle's transient flags (ADR-0010 §7).
- The upkeep's MP change is shown through ADR-0006's ROUND snapshot, which is taken after upkeep. No outcome is emitted.

**Side-effect-free predicates.** `specials_allowed()` and `move_allowed()` **must** have no side effects and draw no RNG. ADR-0010's `check_command()` calls them as queries, possibly several times per turn.

**3. Typed enemy actions.** `EnemyAction` (`src/battle/factions/enemy_action.gd`) is a `RefCounted` value object with two fields:
- `move: Move`;
- `target: Combatant`, which is `null` for `SELF`-target moves (Defend).

`choose_enemy_action()` returns `Array[EnemyAction]` in resolution order, so a compound turn such as Defend then Attack is two entries. An empty array means the enemy does nothing this turn. ADR-0010 §4 resolves the actions in order.

**4. `FactionRuleRegistry`: explicit registration, no reflection, no hidden lookups (TR-factionrules-002).**

```gdscript
class_name FactionRuleRegistry extends RefCounted
func register(rule_class: StringName, factory: Callable, validator: Callable) -> void
func create(faction: FactionData, rule: FactionRuleData) -> FactionRule
func known_rule_classes() -> PackedStringArray
func validator_for(rule_class: StringName) -> Callable
```

**Registration.**
- `rule_class` is a stable vocabulary ID owned by this system (`&"bureaucratia_permit"`, `&"megacorp_billing"`), never a script class name.
- `factory` is `func(faction: FactionData, rule: FactionRuleData) -> FactionRule`.
- `validator` is `func(rule: FactionRuleData) -> Array[Dictionary]` (structured entries, ADR-0004 §4 as amended 2026-10-23). It is pure and checks the class's `params`, `texts` and colours (§5).
- Registration is explicit, in `FactionRules.register_all(registry)` (`src/battle/factions/faction_rules.gd`), the one list of rule classes.

**Boot (ADR-0004 §1 step 2, annotation).** `ContentBootstrap.run()`:
1. creates the `FactionRuleRegistry`;
2. calls `FactionRules.register_all(registry)`;
3. registers one record validator with the catalog: for `faction_rule` records, `rule_class` must be in `known_rule_classes()` and `validator_for(rule_class)` must pass. Both checks look only at the given record and the registry, which is boot-time vocabulary like ADR-0001's known effect types. Purity is kept;
4. returns the registry in its boot result.

`GameRoot` passes the registry to the Battle mode's `BattleFactory`. It is not an autoload, and it is read-only after boot.

**Faction → rule references** use the catalog's **generic reference pass** (Content Data Rule 8: "every reference resolves to a record of the correct type"). `Faction.rule_id` is an ordinary reference field to `faction_rule`. The `faction` record needs no new validator. Rule 8 already rejects a `rule_id` on a `human_nation`.

**`create()` does no lookups.** `BattleFactory` (ADR-0010 §3), which already holds the catalog, does the lookup:
1. it looks up the `Faction` record by `descriptor.faction_id`;
2. it follows `rule_id` to the `FactionRuleData`;
3. it calls `registry.create(faction, rule)`.

An unregistered `rule_class` there is a programming error, because validation already passed. `create()` then logs and returns `null`, and `BattleFactory` reports a build failure.

*Amendment to ADR-0001 (annotation only):* `rule_id` no longer resolves through `ProjectSettings.get_global_class_list()`. Renaming a script class can no longer break content. A rule class that isn't registered is a boot error, not a silent neutral rule.

**5. The `FactionRule` record type (reserved by ADR-0001) is defined.** `FactionRuleData` (`src/data/records/faction_rule_data.gd`) has record type `faction_rule`, ID prefix `rule_`, and lives in `data/faction_rules/rule_<name>.tres`. It is data only:

| Field | Type | Contents |
|---|---|---|
| `rule_class` | `StringName` | §4's vocabulary |
| `ref_ids` | `PackedStringArray` | Every record the rule refers to: named-attack `move_` IDs and roster `enemy_` IDs. IDs carry their type prefix and are unique catalog-wide, so the **generic reference pass** resolves each one with no rule-specific lookup |
| `params` | `Dictionary` | `String` keys → `int`, `float`, `bool` or `String`; types round-trip in `.tres` (probed) |
| `texts` | `Dictionary` | `String` keys → player-visible template strings (Content Data Rule 6), e.g. `"banner_locked": "No special moves until round {unlock_round}."` |
| `colors` | `Dictionary` | `String` keys → hex strings for faction-specific presentation states beyond the identity colour, e.g. Bureaucratia's `"banner_unlocked": "#b07a12"` |

- **Validators are pure.** A class validator checks that its required keys are present, typed and in range, and that **every ID-valued param also appears in `ref_ids`**. That check looks only inside the record. The generic pass guarantees that `ref_ids` resolve.
- **What moves to data:**

  | Rule | Params | Named attacks (`ref_ids`, as `Move` records) |
  |---|---|---|
  | Bureaucratia | `permit_rounds` 3, `low_hp_threshold` 0.5 | `late_fee_move`, `mass_audit_move`, `final_notice_move`, `hunker_jab_move`, `focus_attack_move` |
  | MegaCorp | `bill_mp` 1 | `laser_scan_move`, `upsell_move`, `layoffs_move`, `hostile_takeover_move` |

  MegaCorp also gets a role map from enemy ID to move role, which replaces its display-name comparison. The rosters (Clerk, Supervisor, Security Drone, Middle Manager, CEO) become `Enemy` records with `faction_id`, and the `make_*()` factories are deleted with the ADR-0001 migration.
- **Identity by record.** `Combatant.record_id: String` (*ADR-0007 §0 annotation*) is immutable, set by `BattleFactory` from the enemy or character record ID, and `""` for harness-built combatants. Rules key on `record_id`, `is_boss` and `faction_id`, never on `display_name`.
  - Bureaucratia's "the Supervisor is the manager" keys on `is_boss`.
  - `SquadSpecials` reads `Combatant.is_boss` directly. `BureaucratiaRule.is_manager()` is deleted with the migration.
- **Text formatting.** A rule fills a template with `String.format()` (`texts.banner_locked.format({unlock_round = n + 1})`). Per ADR-0013, `FactionRuleData` lists `texts` in its `LOC_FIELDS`. Each template is extracted with context `<rule_id>.texts.<key>`, and the rule reads it through `LocText.of_key()` before formatting.

**6. Behaviour is unchanged by the migration.** Each rule's decisions stay as shipped: when Specials unlock, how the AI picks, what billing charges. Only where the numbers, names, colours and text come from changes. The characterization tests (ADR-0001 Migration Step 0) cover both factions' behaviour before any rule code moves, including MegaCorp's per-enemy move choice.

### Architecture Diagram

```
 ContentBootstrap.run(catalog)  (ADR-0004 §1, composition root)
   step 2 ─► registry := FactionRuleRegistry.new(); FactionRules.register_all(registry)
               register(&"bureaucratia_permit", BureaucratiaRule.from_data, BureaucratiaRule.validate_record)
               register(&"megacorp_billing",   MegaCorpRule.from_data,     MegaCorpRule.validate_record)
           ─► catalog.register_record_validator(&"faction_rule", registry-bound: class known + class validator)
   step 4 ─► catalog.load_all()   (generic pass resolves Faction.rule_id and FactionRuleData.ref_ids)
   returns { …, faction_rules: registry }  ─► GameRoot ─► Battle mode's BattleFactory

 data/factions/faction_bureaucratia.tres ── rule_id ──► data/faction_rules/rule_bureaucratia_permit.tres
                                                          rule_class = &"bureaucratia_permit"
                                                          ref_ids = [move_late_fee, …]
                                                          params  = { permit_rounds: 3, low_hp_threshold: 0.5,
                                                                      late_fee_move: "move_late_fee", … }
                                                          texts   = { banner_locked: "…{unlock_round}…", … }
                                                          colors  = { banner_unlocked: "#b07a12" }

 BattleFactory (has catalog) ─ get_record(faction) → get_record(rule_id) ─► registry.create(faction, rule)
 BattleCore ── specials_allowed / move_allowed (pure) / choose_enemy_action → Array[EnemyAction]
            ── apply_round_upkeep (MP only) / register_resolution_hooks (ADR-0007)
 BattleHud  ── banner / tooltip text (record templates) / colours (record) — never branches on the rule
```

### Key Interfaces

```gdscript
## src/battle/factions/faction_rule.gd — neutral default; not @abstract
class_name FactionRule extends RefCounted
static func from_data(faction: FactionData, rule: FactionRuleData) -> FactionRule
static func validate_record(rule: FactionRuleData) -> Array[Dictionary]     # base: texts/colors shape only; ADR-0004 §4 entry shape
func _configure(faction: FactionData, rule: FactionRuleData) -> void        # the only place fields are written
func specials_allowed(round_number: int) -> bool                            # pure
func move_allowed(actor: Combatant, move: Move) -> bool                     # pure
func apply_round_upkeep(living_squad: Array[Combatant]) -> void             # MP only
func register_resolution_hooks(hooks: ResolutionHooks) -> void              # ADR-0007
func choose_enemy_action(enemy: Combatant, living_squad: Array[Combatant],
                         round_number: int, rng: RandomNumberGenerator) -> Array[EnemyAction]
func get_banner_text(round_number: int) -> String
func get_tooltip_text(round_number: int) -> String
func get_combatant_tooltip_note(combatant: Combatant) -> String
func get_identity_color() -> Color          # Faction.signature_color; transparent = none (fallback rule)
func get_banner_color(round_number: int) -> Color

## src/battle/factions/enemy_action.gd
class_name EnemyAction extends RefCounted
var move: Move
var target: Combatant                        # null for SELF-target moves

## src/battle/factions/faction_rule_registry.gd — built by ContentBootstrap; read-only after boot
class_name FactionRuleRegistry extends RefCounted
func register(rule_class: StringName, factory: Callable, validator: Callable) -> void
func create(faction: FactionData, rule: FactionRuleData) -> FactionRule
func known_rule_classes() -> PackedStringArray
func validator_for(rule_class: StringName) -> Callable

## src/battle/factions/faction_rules.gd — the one list of rule classes
class_name FactionRules
static func register_all(registry: FactionRuleRegistry) -> void

## src/data/records/faction_rule_data.gd — record type faction_rule, prefix rule_
class_name FactionRuleData extends Resource
@export var id: String
@export var rule_class: StringName
@export var ref_ids: PackedStringArray     # resolved by the generic reference pass
@export var params: Dictionary             # String → int | float | bool | String
@export var texts: Dictionary              # String → player-visible template
@export var colors: Dictionary             # String → "#rrggbb"

## Amendments (annotation only)
# ADR-0001: Faction.rule_id is a generic reference to faction_rule; no get_global_class_list()
# ADR-0004 §1 step 2: run() builds the registry, registers the faction_rule validator, returns the registry
# ADR-0007 §0: Combatant gains `record_id: String` (immutable, identity only; never read by the resolver)
```

### Implementation Guidelines
- `BattleCore`, the Battle mode, `SquadSpecials` and every HUD widget **must never** reference a rule subclass (`BureaucratiaRule.`, `MegaCorpRule.`, `is BureaucratiaRule`, `get_script()`, class-name strings) or compare faction IDs to change behaviour. The CI grep covers any such reference outside `src/battle/factions/`.
- A `FactionRule` subclass **must not** hold mutable per-battle state. Fields **must** be written only in `_configure()`, and the same applies to the modifiers and overrides it registers.
- `specials_allowed()` and `move_allowed()` **must** be side-effect-free and draw no RNG.
- `apply_round_upkeep()` **may** change only MP. A rule **must not** write HP or Turn Battle's transient flags.
- A rule **must** draw randomness only from the `rng` argument.
- Rule tuning, rosters, named attacks, colours and player-visible text **must** be data. Rule scripts **must not** declare numeric tuning `const`s, colour constants or display strings.
- A rule **must** identify combatants by `record_id`, `is_boss` or `faction_id`, never by `display_name`.
- Every non-void override **must** `return` on every path. A miss is a hard parse error on 4.7 (probed).
- A record validator **must** look only at its record and the boot-time registry. Every ID a rule's params name **must** also be listed in `ref_ids`.
- A new rule class **must** be added to `FactionRules.register_all()` with a validator, and its ADR or story **must** name that line.

## Alternatives Considered

### Alternative 1: Resolve `rule_id` by reflection (`ProjectSettings.get_global_class_list()`)
- **Description**: ADR-0001's sketch. `rule_id` names a `class_name`, which is found by scanning.
- **Pros**: No registration code.
- **Cons**:
  - A script rename breaks shipped content.
  - Any subclass, test doubles included, becomes reachable from content.
  - A class with no validator loads unchecked.
- **Rejection Reason**: Explicit registration costs one line per rule and validates every reachable rule.

### Alternative 2: Split the contract now into rules, enemy AI and presentation
- **Description**: GDD Open Question 1, Option B, extended to AI (`Enemy.ai_profile_id` is reserved).
- **Pros**: Smaller interfaces. AI could vary per enemy.
- **Cons**: Three objects and three registries for two factions, with no behaviour that needs them. The AI split depends on an Enemy AI system that has no GDD.
- **Rejection Reason**: Premature. Both splits can be added later without breaking anything (§1, and a future Enemy AI ADR).

### Alternative 3: A cross-record validator phase in ADR-0004
- **Description**: Let rule validators read other records (move IDs, the faction's rule) through a read-only catalog view.
- **Pros**: IDs can sit anywhere in `params`.
- **Cons**: Weakens ADR-0004 §4's purity rule for every validator, and duplicates the generic reference pass.
- **Rejection Reason**: `ref_ids` gives the generic pass everything it needs, and keeps validators pure.

### Alternative 4: Typed parameter records per rule class
- **Description**: `BureaucratiaRuleData extends FactionRuleData` with typed `@export`s.
- **Pros**: Typed in the Inspector.
- **Cons**: One data script per rule class, and ADR-0001's unknown-field check would need to know every subclass.
- **Rejection Reason**: One record type with per-class validators keeps factions as content. Dictionary types round-trip intact (probed).

### Alternative 5: Text as `tr()` keys in code
- **Description**: The first draft. Rules return `tr(&"RULE_…")`.
- **Pros**: Ready for translation.
- **Cons**: Puts player-visible text in code, against Content Data Rule 6, and pre-empts the Localization ADR.
- **Rejection Reason**: TD review. Templates live in the record, and Localization decides how they are extracted.

### Alternative 6: Stateful rules
- **Description**: Rules remember things across turns.
- **Pros**: More expressive rules.
- **Cons**: Retry would need a rule snapshot.
- **Rejection Reason**: Statelessness is what makes Retry free. A rule that needs memory derives it from combatant state, or a later ADR adds rule state to the Retry snapshot explicitly.

## Consequences

### Positive
- `BattleCore`, the HUD and the squad code stay faction-agnostic by rule, enforced by CI, not by habit.
- A new faction is a set of records (`Faction`, `FactionRule`, `Enemy`, `Move`) plus at most one rule class with one registration line.
- Every rule reachable from content is validated at boot, with pure validators.
- Tuning, colours and text move to data. `/balance-check` and the Localization pipeline can read them.
- Retry needs no rule snapshot.

### Negative
- `params`, `texts` and `colors` are untyped dictionaries, so each rule class needs a hand-written validator.
- Annotation amendments to ADR-0001, ADR-0004 and ADR-0007 (the new `Combatant.record_id` field).
- `ref_ids` repeats the IDs that `params` names. The validator enforces that the two agree.
- The migration touches both shipped rules, their rosters and `specials.gd`. Characterization tests pin the behaviour first.

## Risks
- **A rule quietly keeps state.** *Mitigation*: a test per rule class calls every method twice with identical inputs, **re-seeding the RNG to the same state before each `choose_enemy_action()` call**, and asserts identical results. Code review checks that no field is written outside `_configure()`.
- **A non-empty wrong-typed array literal** returned from `choose_enemy_action()` fails at runtime. *Mitigation*: per-rule characterization tests exercise every branch.
- **Presentation outgrows the class.** *Mitigation*: the split described in §1 can be added later without breaking anything.
- **Localization changes the text fields' shape.** *Mitigation*: about ten strings today, all in two records.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| faction-rule-modifiers.md | TR-factionrules-001: stateless contract with neutral defaults; `BattleCore` and the HUD never branch on the subclass | §1 contract, §2 statelessness, Implementation Guidelines and CI grep |
| faction-rule-modifiers.md | TR-factionrules-002: `Faction.rule_id` maps to a class through a registry owned by this system, not Foundation | §4 registry built by the bootstrap; generic reference for `rule_id` |
| faction-rule-modifiers.md | Open Question 1: hook contract shape | §1 (Option A, logged for user veto; a split can be added later) |
| faction-rule-modifiers.md | Tuning Knobs: `PERMIT_ROUNDS`, `LOW_HP_THRESHOLD`, `BILL_MP`, named-attack powers, rosters | §5 data |
| faction-rule-modifiers.md | Edge case: boss immunity keyed on `is_boss`, not on the Supervisor | §5 identity by record; `is_manager()` deleted |
| content-data-definitions.md | Faction `rule_id`; the reserved `FactionRule` type; "Same alien, every screen"; Rule 6 (text in records) | §4, §5; colour from `signature_color`; text templates in the record |
| stats-damage-resolution.md | Rules never compute damage; modifiers register through hooks | §2, ADR-0007 |

## Performance Implications
- **CPU**: unchanged. The calls per turn and per round are the same. `create()` runs once per battle, during SWAP.
- **Memory**: one rule instance per battle, plus one small record per rule.
- **Load Time**: one more validator during the Validating phase, which is negligible.

## Migration Plan
1. **Step 0 (ADR-0001):** characterization tests of both rules' decisions:
   - the round when Specials unlock;
   - the AI's picks before and after the permit;
   - MegaCorp's per-enemy move choice;
   - billing and suspension.
2. **Typed actions:** `EnemyAction` and the typed `choose_enemy_action()` return. `BattleCore` consumes it (ADR-0010 §4).
3. **Registry and identity:**
   - `FactionRuleRegistry`, `FactionRules.register_all()`, `from_data()`/`_configure()`;
   - the `faction_rule` validator, and the registry returned from `ContentBootstrap.run()`;
   - `Combatant.record_id`.

   Until the records exist, `register_all()` also exposes each class's in-code defaults, so the interim code-factory path can build rules.
4. **Data migration, with ADR-0001 Migration Step 3:**
   - add `FactionRuleData` records, populate `Faction.rule_id`, and add named attacks as `Move` records and rosters as `Enemy` records;
   - MegaCorp's role map keys on enemy IDs, and `SquadSpecials` reads `is_boss`;
   - delete the `const` tuning, colour and text constants, the `make_*()` factories and `is_manager()`;
   - `BattleFactory` calls `registry.create()`.

## Validation Criteria
- **Statelessness:** every `FactionRule` subclass returns identical results for identical inputs across repeated calls, with the RNG reseeded before each AI call.
- **Boot validation fails, with one error each,** for:
  - a `faction_rule` record with an unregistered `rule_class`;
  - a missing or wrong-typed param;
  - an ID-valued param not listed in `ref_ids`.
- **Reference pass:** a `ref_ids` entry or `Faction.rule_id` naming a missing record fails the generic reference pass.
- **Characterization:** after the migration, the Step 0 characterization tests pass unchanged.
- **CI grep:**
  - no `BureaucratiaRule.` / `MegaCorpRule.` / faction-ID comparisons outside `src/battle/factions/`;
  - no `display_name` comparisons in rule classes;
  - no numeric, colour or display-string `const` in rule classes.

## Related
- **Depends on:**
  - `adr-0001-content-data-storage-format.md` (amended additively, §4–§5);
  - `adr-0004-content-boot-ordering.md` (§1 step 2, amended additively);
  - `adr-0007-stats-damage-resolution.md` (`register_resolution_hooks`; `Combatant.record_id` annotation);
  - `adr-0013-localization.md` (`LOC_FIELDS` for `texts`; `tr()` with context for the fallback sentences).
- **Enables:** `adr-0010-turn-battle-system.md` (`EnemyAction`, `FactionRuleRegistry`, `record_id`).
- **GDDs:**
  - `design/gdd/faction-rule-modifiers.md` (Open Question 1 answered: Option A, pending user veto);
  - `design/gdd/content-data-definitions.md` (the `FactionRule` record type is now defined).
- **Upcoming:**
  - the Enemy AI ADR (may move AI behind `Enemy.ai_profile_id`);
  - the Localization ADR (extraction of record text).

## Review History
| Date | Reviewer | Verdict | Notes |
|------|----------|---------|-------|
| 2026-10-22 | technical-director (TD-ADR) | CONCERNS → revised | **3 blocking, all fixed:**<br>- Validators broke ADR-0004 §4 purity. Fixed: `rule_id` and `ref_ids` go through the generic reference pass; params IDs must appear in `ref_ids`.<br>- The registry was unreachable and `create()` hid a catalog lookup. Fixed: the bootstrap returns the registry, and `create(faction, rule)` is called by `BattleFactory` after its lookups.<br>- MegaCorp's display-name keying. Fixed: `Combatant.record_id`, and a role map keyed by enemy ID.<br>**Advisories folded in:** shipped neutral defaults; the hook attributed to ADR-0007; the fallback colour; the amber in `colors`; text templates in the record instead of `tr()` keys; statelessness extended to registered modifiers, with the RNG reseeded in tests; the MP citation; `specials.gd` `is_manager`; Open Question 1 logged for user veto; `EnemyAction.target` null for self moves |
| 2026-10-22 | godot-specialist | APPROVE WITH NOTES | Probed:<br>- Callables to constructors and `from_data`;<br>- `.tres` Dictionary types (no coercion needed; risk removed);<br>- `StringName` round-trip;<br>- typed-array override and `[]` coercion;<br>- the missing-return hard parse error |
| 2026-10-22 | `/architecture-review` (`architecture-review-2026-10-22b.md`) | CONCERNS → fixed | Undeclared dependency: §5 lists `texts` in ADR-0013's `LOC_FIELDS` and the fallback rule uses ADR-0013's `tr()` convention, but ADR-0013 was not under Depends On. Fixed: ADR-0013 added to Depends On and Related. godot-specialist: PASS, no engine findings |
| 2026-10-22 | User | **Accepted** | Explicit instruction (order ADR-0013 → ADR-0008 → ADR-0009 → ADR-0011 → ADR-0010). Dependencies ADR-0001, 0004, 0007 and 0013 are Accepted. No story was Blocked on this ADR. Its additive amendments to ADR-0001 (`rule_id` as a reference to a `faction_rule` record; the `FactionRule` record type defined), ADR-0004 §1 step 2 (`FactionRuleRegistry` built and returned by `ContentBootstrap.run()`) and ADR-0007 §0 (`Combatant.record_id`) are annotated in their Status sections. Open Question 1's Option A stays logged for user veto |
