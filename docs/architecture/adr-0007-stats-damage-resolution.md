# ADR-0007: Stats & Damage Resolution — One Pure Resolver, Per-Attempt Hooks, Data-Driven Constants

## Status
Accepted — amended by ADR-0011 (§0: `Combatant` gains the immutable `record_id: String`, set at construction; identity, not a stat, never read by the resolver; Accepted 2026-10-22, amendment in effect, annotation only)

## Date
2026-10-22

## Last Verified
2026-10-22

## Decision Makers
User (autonomous mode — decisions logged in `production/session-logs/decision-log.md`), Claude (orchestrating session), reviewed by godot-specialist (engine validation, probed on 4.7.2) and technical-director (TD-ADR). Retroactive: the damage math already ships in `src/battle/` (MVP epic, Stories 001–004). This ADR records what stays, and decides the architecture for the parts of the GDD the code doesn't yet implement.

## Summary
Stats & Damage Resolution (`design/gdd/stats-damage-resolution.md`) requires a fixed six-step pipeline with injected tuning constants, a registration interface for other systems' modifiers and overrides, a single writer of `current_hp`, and one outcome record per resolution (TR-stats-001..004). The shipped code gets the math right (F3–F7), but the two F5 modifiers are hardcoded, there is no Override step, the constants are `const`, HP is written from several places, and nothing is reported for a move that fails to resolve.

Decided: a pure, stateless `DamageResolver` runs all six steps for both `damage` and `heal`, against a `ResolutionHooks` registry rebuilt for every battle attempt and an injected `StatsConfig` resource. It is the only code that changes HP during a battle (`Combatant.hp` becomes a read-only property), and it returns one `ResolutionRecord` per effect, which `BattleOutcome` carries. Defend and Viral Stunt become ordinary registered modifiers. Faction rules register theirs through one new `FactionRule` hook, and Stats registers its own content-range validator through ADR-0004's bootstrap.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scripting: pure functions, `RefCounted`, `Resource`) |
| **Layer** | Core |
| **Knowledge Risk** | LOW — no post-cutoff API is introduced. The decision uses only `RefCounted`, `Resource` with typed `@export`s, typed `Array`s, property getters/setters, `RandomNumberGenerator` (injected) and `Callable`, all already exercised by the shipped battle code |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (only the 4.7 typed-return override row and the packed-array setter row apply), `deprecated-apis.md`, `current-best-practices.md` (no `modules/core.md` exists) |
| **Post-Cutoff APIs Used** | None. 4.7's "an override of a typed method inherits its return type" applies to the **non-void** virtuals (`applies`, `flat_for`, `pct_for`, `override`): every subclass override must `return` on every path, or the script fails to load ("Not all code paths return a value", probed). The `void` hook `FactionRule.register_resolution_hooks()` needs no `return` |
| **Verification Required** | **Probed on 4.7.2 (godot-specialist, 2026-10-22):**<br>(1) the new classes reference each other's enums (`DamageResolver.EffectType`, `ResolutionRecord.Result`) with no cyclic-reference error;<br>(2) one-line bodies (`func x() -> bool: return true`) compile, and `override` is not a reserved word;<br>(3) `Array[DamageResolver.EffectType]` compiles; at runtime it is an `Array[int]` and `in` works;<br>(4) `randf_range()` is exactly one RNG draw, and saving and restoring `rng.state` reproduces the next value, so a characterization test of RNG state is sound;<br>(5) `assert()` aborts the current function in debug builds and is stripped, with its expression unevaluated, in release exports;<br>(6) `StringName < StringName` is **not** alphabetical (an internal order), and `Array.sort_custom()` is **not stable**, hence §3's explicit comparator;<br>(7) `floor(100 × (1 + 0.15))` gives 114, from floating-point error, hence F2's epsilon (§1);<br>(8) GDScript enums are plain ints and aren't range-checked at runtime, hence §1's runtime checks;<br>(9) a property setter can refuse a write (`push_error`, value unchanged), and the underscore convention isn't enforced, hence §2's read-only `hp`;<br>(10) a rough resolution (context, request, record, 8 modifiers, 2 overrides, one draw) took about 4.7 µs.<br>**Still to measure:** the 50 µs median (TR-stats-001) on a release-template build, in Validation Criteria |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Content Data storage format, **Accepted**): `stat_block`, `Move` cost and effect fields come from catalog records, and the factories that build `Combatant`/`Move` stay adapters. ADR-0004 (Content Boot Ordering, **Accepted**): `ContentBootstrap.run()` and `register_record_validator()`, through which Stats registers its range validators (§7) |
| **Enables** | The retroactive Faction Rule Modifiers ADR (rules register modifiers and overrides through §3's one new hook); the retroactive Turn Battle System ADR (it calls the resolver and owns Defend's modifier); a future Quirk State System ADR (quirks register through the same registry); Items/Equipment (Vertical Slice: equipment stat modifiers) |
| **Blocks** | ADR-0001's migration Step 3 (the battle factories read the catalog) should land after this ADR's Migration Step 2, so the factories are rewritten against `StatsConfig`, not today's `const`s. Any story adding a new damage or heal source |
| **Ordering Note** | Amends ADR-0001 additively (annotation only, §7): "numeric ranges are read from a constants reference owned by Stats & Damage Resolution" becomes "Stats & Damage Resolution registers its range validators through `ContentBootstrap`". ADR-0001's text is kept; the amendment takes effect when this ADR is Accepted. Adds one line to ADR-0004 §1's registrant list (ADR-0004 requires the introducing ADR to name it: §7). Does not change ADR-0006: `BeatPlan` builds from snapshots, every emitted outcome is `RESOLVED`, and non-resolving moves change no state and are never emitted (§5) |

## Context

### Problem Statement
`/architecture-review` (2026-10-22) returned FAIL partly because TR-stats-001..004, all Core-layer requirements, have no ADR. The code exists and works, so the gap isn't only paperwork: the GDD makes promises the code doesn't keep, and three upcoming systems (Quirk State, the next two factions, Items) need a place to plug in that doesn't exist yet. Today, adding a damage modifier means editing `DamageCalculator` itself. An Override (Bureaucratia's original "damage is 0 until Approved" design) has nowhere to go. A future quirk or item that heals would have to copy `SquadSpecials.heal_single()`'s direct `Combatant.heal()` call, adding another HP writer.

What exists (`src/battle/`, read 2026-10-22):
- `DamageCalculator.calculate_damage(attacker, defender, power, rng)`: static and pure. It implements F3 (with `attack_eff = max(1, attack)`, `defense_eff = max(0, defense)`), F5 with two hardcoded terms (`DEFEND_PCT = −0.5` when `is_defending`, `VULNERABLE_PCT = +0.5` when `vulnerable_rounds_left > 0`), F6 (`rng.randf_range(0.9, 1.1)`) and F7 (round half up, clamp 1–999). The constants are `const`.
- `SquadSpecials.calculate_heal(power, healer)`: F4 plus round half up. No F5, no F7 clamp, no RNG draw.
- No F2 (effective stats): raw stats are used, with only the `attack ≥ 1` guard.
- No Override step.
- `Combatant.hp` is a public `var`. It is written by `take_damage()`/`heal()` (called from `BattleCore._apply_damage()` and `SquadSpecials.heal_party()`/`heal_single()`), by `reset_for_battle()`, by `ChapterFlow`'s snapshot restore (`chapter_flow.gd:160`) and by the HUD demo's debug knockout (`battle_hud_demo.gd:85`).
- `BattleOutcome` carries one `hp_delta` per action (the side total for a party heal), with no per-effect record, no `overridden`, no `skipped`, and no `unaffordable`/`no_target` result. `submit_action()` returns `null` for an illegal squad action. The enemy phase silently skips an action whose target was knocked out earlier in the same compound turn (`battle_core.gd:288`), with no RNG draw. `_resolve_move()` spends MP without an affordability check, which is safe today because every enemy move costs 0.
- `BattleCore.rng` is one instance, shared by damage variance and `faction_rule.choose_enemy_action()`.

### Constraints
- **Gameplay numbers must not change.** The battle prototype passed two playtests, and the MVP epic is Done. With the same RNG seed, every shipped move must deal and heal exactly what it does today, and the RNG must advance exactly as today (Migration Step 0 pins this). The one intended difference is reporting: Migration Step 4 adds log-only `NO_TARGET` entries to `outcome_log` where today's code skips silently. Those entries change no state and are never emitted.
- **`BattleCore`'s public contract and signals stay** (ADR-0006 builds on them). `BattleCore.new()` gains only a trailing, defaulted parameter. `BattleOutcome` may gain fields; none may change meaning.
- **No global state** (TR-stats-002, Architecture Principle 5): the RNG is injected, and so is everything else.
- **No upward imports** (Principle 7): Core may not import Feature types; Foundation (`src/data/`) may not import Core.
- **Data-driven tuning** (coding standards): `power_scale`, variance, the multiplier clamp, caps and floors are data.

### Requirements
- TR-stats-001: the fixed Base → Modify → Vary → Round and clamp → Override → Apply pipeline (F2–F8), tuning constants injected, median under 50 µs per resolution.
- TR-stats-002: RNG always injected, never global.
- TR-stats-003: a registration interface for step-2 modifiers and step-5 overrides, ordered by priority with a stable tie-break.
- TR-stats-004: `current_hp` written only by Apply; exactly one outcome record per resolution, including `unaffordable` and `no_target`.
- TR-stats-005 (partial): F1 ranges and the `max_hp`/`max_mp` modifier ban checked at content validation.

## Decision

### 0. `Combatant` is a Core type owned by Stats & Damage
`Combatant` (`src/battle/combatant.gd`) holds the stat block and the runtime `hp`/`mp` that GDD Core Rules 1–3 give this system. It is a **Core** type, owned by Stats & Damage Resolution, and the resolver may read and change it without importing Feature code.
- It also carries Turn Battle's per-fight flags (`is_defending`, `is_stunned`, `vulnerable_rounds_left`) and `is_enemy`/`is_boss`. That is **accepted interim debt**: those fields belong to Turn Battle, they are set and cleared only by Feature code, and they are read only by Feature-registered modifiers (§3), **never by the resolver**. The retroactive Turn Battle System ADR decides whether they move to a Turn Battle side-table.
- **Nothing in `src/battle/stats/` may reference `BattleCore`, `FactionRule`, `BattleOutcome`, `Move`, `SquadSpecials` or any other Feature type.** `Combatant`, `StatsConfig` and the `src/battle/stats/` classes are the whole Core surface. A CI grep checks it (Validation Criteria).
- The directory doesn't move (`combatant.gd` stays in `src/battle/`), so no `.tres` or scene path changes.

### 1. `DamageResolver`: one pure function for both effect types
`DamageResolver` (`src/battle/stats/damage_resolver.gd`, `RefCounted`, static functions only) is the only implementation of the GDD's pipeline. `resolve(request: ResolutionRequest) -> ResolutionRecord` runs these steps, in order, for one effect against one target:

1. **Validity.** If `effect_type` isn't `DAMAGE` or `HEAL` (enums aren't range-checked at runtime), `push_error()` naming it and return a record with `result = INVALID_EFFECT`; nothing is applied and no RNG is drawn. The primary GDD Core Rule 7 check sits one step earlier, where `BattleCore`'s adapter maps a move's effect `type` string to an `EffectType`: an unowned type string produces the same `INVALID_EFFECT` record without calling the resolver.
2. **Skip check.** If the target is knocked out, return a record with `skipped = true`, `final_amount = 0`, `hp_change = 0`, applying nothing and drawing nothing (GDD Edge Cases: no number shown). A `heal` on a knocked-out target is skipped the same way (GDD States: heal has no effect on Knocked Out).
3. **Base (F2, then F3 or F4).** Effective stats come from F2 over the registry's stat modifiers: `stat_eff = clamp(floor((stat + Σflat) × (1 + Σpct) + 1e-6), stat_eff_min, stat_eff_max)`, with `stat_eff_min = 1` for `attack` and 0 otherwise. The `1e-6` absorbs floating-point error, so `100 × (1 + 0.15)` gives 115, not 114 (probed). Then F3 for `damage` (`(power / power_scale) × attack_eff² / (attack_eff + defense_eff)`) or F4 for `heal` (`power × (1 + attack_eff / heal_attack_scale)`).
4. **Modify (F5).** `max(0, base + Σflat) × clamp(1 + Σpct, mult_min, mult_max)`, over the amount modifiers that apply to this request. `Σflat` is an integer sum (GDD F5).
5. **Vary (F6).** `× rng.randf_range(1 − v, 1 + v)` with `v = damage_variance`. **Heals never call the RNG.** The draw is skipped, not multiplied by 1, so adding or removing a heal never shifts a seeded sequence.
6. **Round and clamp (F7).** `clamp(floor(x + 0.5), min_amount, amount_cap)`, with the effect type's floor and cap. No epsilon here: the variance draw is continuous, so exact .5 ties don't arise in practice.
7. **Override.** Each applicable override runs in §3's order and sees the previous result. Each result is clamped to `0 .. amount_cap`. `overridden` is true if any override applied, even if it returned the same value. Only an override can produce 0.
8. **Apply (F8).** For `damage`, `new_hp = clamp(hp − final_amount, 0, max_hp)`; for `heal`, `new_hp = clamp(hp + final_amount, 0, max_hp)`. The resolver calls `target._apply_hp(new_hp)`. The record carries both `final_amount` (after step 7) and `hp_change` (`new_hp − old_hp`, the HP that actually moved).

`resolve()` has no hidden inputs. `ResolutionRequest` carries `user`, `target`, `effect_type`, `power`, the `ResolutionHooks`, the `StatsConfig`, the `round_number` and the `RandomNumberGenerator`. **The RNG is `BattleCore.rng`, the same instance `faction_rule.choose_enemy_action()` uses**, never a new or second one, so the seeded sequence stays exactly as today.

The resolver's other public functions:
- `can_afford(user, cost) -> bool` (GDD Core Rule 5);
- `effective_stat(c, stat, hooks, config) -> int` (F2), for Turn Battle's turn order and Enemy AI's read-only queries. Outside a resolution it builds a context with `subject = c`, `user = c`, `target = null`, `effect_type = NONE`, so a stat modifier that keys off a target or effect type simply doesn't apply.

### 2. Who writes HP
- **`Combatant.hp` is a read-only property.** It reads a private backing field, `_hp`, and its setter refuses every write: it calls `push_error("hp is written only via _apply_hp or restore_vitals (ADR-0007 §2)")` and leaves the value unchanged. Probed: the setter fires and HP doesn't change. `take_damage()` and `heal()` are removed.
- **During a battle, only `DamageResolver`'s Apply step changes HP**, through `Combatant._apply_hp(new_hp: int)`, which clamps to `0 .. max_hp` and writes `_hp`.
- **Non-resolution writers use one public method**, `Combatant.restore_vitals(hp: int, mp: int)`, which clamps both and writes `_hp`/`mp`. Its permitted callers, each named in the lint's allowlist with the section that permits it:
  - `Combatant.reset_for_battle()` (a full reset at battle start or a standalone Retry);
  - the Battle mode's Retry snapshot restore (ADR-0002 §7, ADR-0006 §5), and `ChapterFlow`'s snapshot restore until ADR-0002 Migration Step 2 deletes it;
  - Camp's full restore (Camp & Party Management; GDD Core Rule 3, provisional);
  - the GDD's provisional "a character knocked out at a won battle's end leaves with 1 HP" rule, when Turn Battle or Camp adopts it;
  - debug-only tools: the HUD demo's knockout button calls `restore_vitals(0, …)` behind `OS.is_debug_build()`, or the demo is deleted with ADR-0002 Migration Step 2.
- **Enforced by a CI lint**, because GDScript doesn't enforce the underscore convention (probed): `tools/ci/lint_hp_writes.sh` fails on any of these outside its allowlist file:
  - a call to `_apply_hp(` outside `src/battle/stats/damage_resolver.gd`;
  - a call to `restore_vitals(` outside the allowlisted files;
  - an assignment to `_hp` (`\b_hp\s*[-+*/]?=`) outside `combatant.gd`;
  - an assignment or compound assignment to `.hp` (`\.hp\s*[-+*/]?=`), and `set(&"hp"` or `set("hp"`, anywhere. These would hit the refusing setter at runtime, so the lint catches them before a test does.
- **MP stays outside this rule.** TR-stats-004 covers `current_hp` only. `spend_mp()` (cost payment) and faction MP drains keep their current paths.

### 3. `ResolutionHooks`: the per-attempt registry
`ResolutionHooks` (`RefCounted`) holds three lists: stat modifiers (F2), amount modifiers (F5) and overrides (step 7).
- **Lifetime: one battle attempt.** `BattleCore` owns one instance, and **`start_battle()` rebuilds it**. It clears every entry, registers the two built-ins, then calls `faction_rule.register_resolution_hooks(hooks)`. Retry reuses the same `BattleCore` (ADR-0002 §7, ADR-0006 §5: restore, then `start_battle(false)`), so rebuilding there means a quirk, combo or equipment modifier registered mid-fight never carries into the retried attempt. It is never a global and never an autoload.
- **Entries are objects** with a `source_id: StringName` and an `applies(ctx: ResolutionContext) -> bool` predicate, so a modifier can depend on the target's state (Defend, Viral Stunt) without the resolver knowing why:
  - `StatModifier`: `stat` (`ATTACK`, `DEFENSE` or `SPEED` only: §7), `flat: int`, `pct: float`. Its `applies(ctx)` reads `ctx.subject`, the combatant whose stat is being computed;
  - `AmountModifier`: `effect_types` (a list of `DAMAGE`/`HEAL`), `flat_for(ctx) -> int`, `pct_for(ctx) -> float`;
  - `AmountOverride`: `priority: int`, `override(ctx, amount: int) -> int`.
- **Runtime checks.** The resolver ignores, with one `push_error()`, a `StatModifier` whose `stat` isn't one of the three (a `match` with a default branch) and an `effect_types` value that isn't a known `EffectType`. GDScript enums are plain ints and aren't checked at runtime (probed).
- **Order.**
  - Each entry gets a monotonic **registration index** when added.
  - **Modifiers** are summed, so their order can't change the result. They are iterated in the original list (registration order), never a sorted copy, so a debug trace is stable.
  - **Overrides** run sorted by: ascending `priority`; then `String(a.source_id) < String(b.source_id)` (plain code-point order; `StringName <` is not alphabetical on 4.7.2, probed); then the registration index. `Array.sort_custom()` isn't stable (probed), so the index is an explicit third key, never left to the sort. That is the GDD's stable tie-break.
- **Registration.** `add_stat_modifier()`, `add_amount_modifier()` and `add_override()`; a duplicate (`source_id`, kind) pair replaces the earlier entry and keeps its index. `remove_source(source_id)` drops everything a source registered (a quirk wearing off).
- **Who registers, at MVP:**
  - **Turn Battle** registers the two built-ins in `start_battle()`: `defend` (`pct = defend_pct` on `DAMAGE` when `ctx.target.is_defending`) and `viral_stunt` (`pct = vulnerable_pct` on `DAMAGE` when `ctx.target.vulnerable_rounds_left > 0`). Their values come from `StatsConfig`, not code. The classes live with Turn Battle (`src/battle/`), not in `src/battle/stats/`, because they read Turn Battle's flags (§0).
  - **Faction rules** register through one new `FactionRule` hook, `register_resolution_hooks(hooks: ResolutionHooks) -> void`, called by `start_battle()` after the built-ins. The base class does nothing. No shipped faction registers anything: Bureaucratia's permit rule bans Specials, and MegaCorp bills MP, so neither touches the pipeline.
  - **Quirk State, Combos and Equipment** register through the same API once they exist (each in its own ADR).
- **The registry is read-only during a resolution.** The resolver brackets each `resolve()` with a debug-only depth counter on the registry (`_resolving_depth`, incremented on entry and decremented on every return path, early returns included). While it is above 0, `add_*` and `remove_source` `push_error()` and change nothing. That counter is the one piece of state the otherwise stateless resolver touches. It is debug bookkeeping, not data the pipeline reads, and it is compiled into release builds only as an integer that is never checked.

### 4. `StatsConfig`: tuning constants as data
`StatsConfig` (`src/battle/stats/stats_config.gd`, a `Resource`; `data/config/stats_config.tres`) is a project config, like ADR-0002's `TransitionConfig` and ADR-0003's `InputConfig`, not a catalog record. It holds every number the pipeline and the validators use (Key Interfaces lists the fields and the GDD defaults).
- **One loader.** `StatsConfig.load_or_default(path) -> StatsConfig` is a static function. It loads the `.tres`, and on a missing or unreadable file it logs an error and returns `StatsConfig.new()`, whose declared defaults equal the GDD's values (as `InputConfig` does). `ContentBootstrap.run()` (for the validators, §7) and `GameRoot._ready()` (for battles) both call it. `ResourceLoader`'s cache means the second call returns the same instance.
- **Injection.** `GameRoot` passes the config to each Battle mode, which passes it to `BattleCore.new(squad, enemies, rng, faction_rule, stats_config := StatsConfig.new())`. The parameter is trailing and defaulted, so `ChapterFlow`, the HUD demo, the debug harness and the Step 0 tests keep compiling.
- **Tests** read thresholds from a config, never literals, and every formula test also runs with a non-default config.

### 5. Outcome records
- **`ResolutionRecord`** (`RefCounted`, value object) carries the fields of GDD Core Rule 11: `user`, `target`, `effect_type`, `final_amount`, `hp_change`, `new_hp`, `overridden`, `skipped` and `result` (`RESOLVED`, `UNAFFORDABLE`, `NO_TARGET`, `INVALID_EFFECT`).
- **`BattleOutcome` gains `records: Array[ResolutionRecord]`** (one per effect per target, in resolution order) **and `result`**. Its existing fields keep their meaning: `hp_delta` stays the sum of the records' `hp_change` (so a party heal still reports the side total), and `target_knocked_out` is unchanged. ADR-0006's `BeatPlan` reads snapshots, not these fields.
- **Affordability runs at resolution for every actor.** `_resolve_move()` checks `DamageResolver.can_afford(actor, cost)` before spending any MP. Squad commands are also checked at submit (the same instant). It can't fail at MVP: every enemy move costs 0, and MegaCorp's billing runs at round end. But it's the hook a mid-turn drain would hit.
- **A move that fails at resolution time** (an enemy action whose target was knocked out earlier in the same compound turn; a cost no longer affordable) produces one `BattleOutcome` with `result = NO_TARGET` or `UNAFFORDABLE`, carrying **exactly one `ResolutionRecord`**: `user`, the intended `target`, `final_amount = 0`, `hp_change = 0` and that `result`. That meets GDD Core Rule 11 literally ("reports one record with `result` = ...").
- **Two invariants protect ADR-0006:**
  - **(a) A non-resolving outcome changes no state at all**: no HP, no MP, no flag, no RNG draw. It is appended to `outcome_log` and **never emitted on `action_resolved`**, so ADR-0006 takes no snapshot for it, and its display invariant (displayed values equal live values on every released TURN and when the queue drains) still holds.
  - **(b) Every emitted outcome has `result == RESOLVED`.** `BattleCore` asserts it at the emit site, so ADR-0006's "every outcome shape has a defined pose" is never handed a non-event.
- **Squad commands are validated before resolution**, as today: `submit_action()` still returns `null` for an illegal command and changes nothing, because the UI only offers legal ones. That is input validation, not a resolution, so it produces no record.

### 6. Turn Battle's call sites
`BattleCore._apply_damage()` and the `HEAL_PARTY`/`HEAL_SINGLE` branches call `DamageResolver.resolve()` instead of `DamageCalculator` and `Combatant.take_damage()`/`heal()`, passing `BattleCore.rng`. `SquadSpecials.calculate_heal()`, `heal_party()` and `heal_single()` are removed: the specials stay as `Move` factories only. Family Meal resolves one `heal` per living squad member, in squad order (GDD Edge Cases: each target resolves separately). The amounts equal today's, because heals draw nothing. Appetizer on a knocked-out ally is already rejected at submit (`battle_core.gd:198`), so the heal skip changes no shipped behaviour. `DamageCalculator` is deleted once Migration Step 2 passes.

### 7. Content validation and the modifier ban
- **Stats registers its own validators** through ADR-0004. `ContentBootstrap.run()` gets `StatsConfig.load_or_default()` and calls `catalog.register_record_validator()` with validators bound to it (`StatsValidators.validate_stat_block.bind(config)`, so they stay pure under ADR-0004 §4):
  - for `character` and `enemy` records: every `stat_block` value inside its F1 range;
  - for `move` records: `cost ≥ 0` (Content Data Rule 8: a non-negative integer, no upper bound), and every `damage`/`heal` `power` inside `power_range` (1–100, F3/F4).

  The validators are pure static functions in `src/battle/stats/stats_validators.gd`. `ContentBootstrap.run()` gains these registration lines (ADR-0004 §1). This replaces ADR-0001's "the catalog reads the ranges from a constants reference owned by Stats" (an annotation-only amendment). As a result, `src/data/` imports nothing from Core, which ADR-0004's import rule requires. `Enemy.reward` ranges (0–9999) are added to the enemy validator with the enemy-record migration.
- **`max_hp` and `max_mp` can't be modified.** That is banned by type when code is written, and checked at runtime:
  - `StatModifier.Stat` has only `ATTACK`, `DEFENSE` and `SPEED`, so no code can name `max_hp` or `max_mp` without a cast;
  - the resolver ignores and reports an out-of-range `stat` value (§3), because a cast can still store one;
  - when Quirk State records carry stat modifiers, their validator (registered the same way) rejects any other stat by name.

  So `current_hp > max_hp` can't happen at MVP (GDD Edge Cases).

### 8. Out of scope
- **F9 rewards.** `RewardTotals.compute(defeated: Array[Combatant]) -> Vector2i` (`xp`, `money`) is a pure function this ADR names but doesn't build: `Enemy.reward` doesn't exist on the runtime `Combatant` yet. It arrives with the enemy-record migration.
- **Which number the player sees** (the GDD's provisional F8, "overkill is shown"): the record carries both `final_amount` and `hp_change`. ADR-0006 shows snapshot deltas (`hp_change`), which contradicts the provisional F8 text. That is a design question for the GDD (see Related), not an architecture one.
- **Speed-ordered turns.** `effective_stat(SPEED)` exists for Turn Battle; today's turn order is squad order, and changing it belongs to the Turn Battle ADR.

### Architecture Diagram

```
 ContentBootstrap.run ── StatsConfig.load_or_default ──► StatsValidators (bound) ──► catalog.register_record_validator
 GameRoot._ready ─────── StatsConfig.load_or_default (same cached instance) ──► Battle mode ──► BattleCore.new(..., stats_config)

 BattleCore (Feature)                                     Core: Combatant, StatsConfig, src/battle/stats/*
   start_battle():  hooks.clear()                         (never imports Feature)
                    ├─ built-ins: defend, viral_stunt  (Turn Battle classes, values from StatsConfig)
                    └─ faction_rule.register_resolution_hooks(hooks)
                    (later: Quirk State, Combos, Equipment via add_* / remove_source)
   _resolve_move:   can_afford? ── no ──► BattleOutcome(UNAFFORDABLE, 1 record) ─► outcome_log only
                    target KO'd (enemy compound turn) ──► BattleOutcome(NO_TARGET, 1 record) ─► outcome_log only
                    else ──► DamageResolver.resolve(ResolutionRequest{..., rng = BattleCore.rng})
                               validity → skip? → F2 → F3|F4 → F5 → F6 (damage only) → F7
                               → overrides (priority, String(source_id), reg. index) → Apply: target._apply_hp()
                             ◄── ResolutionRecord ──► BattleOutcome(RESOLVED).records ─► outcome_log + action_resolved
```

### Key Interfaces

```gdscript
## src/battle/stats/damage_resolver.gd — pure, static, headless-testable
class_name DamageResolver extends RefCounted
enum EffectType { NONE, DAMAGE, HEAL }
static func resolve(request: ResolutionRequest) -> ResolutionRecord
static func can_afford(user: Combatant, cost: int) -> bool
static func effective_stat(c: Combatant, stat: StatModifier.Stat, hooks: ResolutionHooks, config: StatsConfig) -> int

## src/battle/stats/resolution_request.gd — a value object
class_name ResolutionRequest extends RefCounted
var user: Combatant
var target: Combatant
var effect_type: DamageResolver.EffectType
var power: int
var round_number: int
var hooks: ResolutionHooks
var config: StatsConfig
var rng: RandomNumberGenerator      # BattleCore.rng; never drawn for HEAL, a skip or an invalid effect

## src/battle/stats/resolution_context.gd — what a modifier or override may read
class_name ResolutionContext extends RefCounted
var subject: Combatant              # whose stat is being computed (F2); the target for F5 and overrides
var user: Combatant
var target: Combatant               # null outside a resolution (effective_stat queries)
var effect_type: DamageResolver.EffectType   # NONE outside a resolution
var round_number: int

## src/battle/stats/resolution_record.gd
class_name ResolutionRecord extends RefCounted
enum Result { RESOLVED, UNAFFORDABLE, NO_TARGET, INVALID_EFFECT }
var user: Combatant
var target: Combatant
var effect_type: DamageResolver.EffectType
var final_amount: int      # after Override; 0 when skipped or not resolved
var hp_change: int         # new_hp - old_hp (negative for damage)
var new_hp: int
var overridden: bool
var skipped: bool
var result: Result

## src/battle/stats/resolution_hooks.gd — one per BattleCore, rebuilt by start_battle()
class_name ResolutionHooks extends RefCounted
func clear() -> void
func add_stat_modifier(m: StatModifier) -> void
func add_amount_modifier(m: AmountModifier) -> void
func add_override(o: AmountOverride) -> void
func remove_source(source_id: StringName) -> void

## Base classes: subclass and override; every non-void override returns on every path (4.7)
class_name StatModifier extends RefCounted
enum Stat { ATTACK, DEFENSE, SPEED }        # max_hp / max_mp deliberately absent (§7)
var source_id: StringName
var stat: Stat
var flat: int
var pct: float
func applies(_ctx: ResolutionContext) -> bool: return true

class_name AmountModifier extends RefCounted
var source_id: StringName
var effect_types: Array[DamageResolver.EffectType]
func applies(_ctx: ResolutionContext) -> bool: return true
func flat_for(_ctx: ResolutionContext) -> int: return 0
func pct_for(_ctx: ResolutionContext) -> float: return 0.0

class_name AmountOverride extends RefCounted
var source_id: StringName
var priority: int
func applies(_ctx: ResolutionContext) -> bool: return false
func override(_ctx: ResolutionContext, amount: int) -> int: return amount

## src/battle/stats/stats_config.gd — project config; defaults equal the GDD
class_name StatsConfig extends Resource
@export var power_scale: float = 10.0          # F3
@export var heal_attack_scale: float = 50.0    # F4
@export var damage_variance: float = 0.10      # F6
@export var heal_variance: float = 0.0         # F6 (heals never draw; kept for the GDD's knob list)
@export var mult_min: float = 0.1              # F5
@export var mult_max: float = 3.0              # F5
@export var min_damage: int = 1                # F7
@export var min_heal: int = 1                  # F7
@export var damage_cap: int = 999              # F7
@export var heal_cap: int = 999                # F7
@export var stat_eff_max: int = 199            # F2
@export var defend_pct: float = -0.5           # built-in modifier (F5)
@export var vulnerable_pct: float = 0.5        # built-in modifier (F5)
@export var max_hp_range: Vector2i = Vector2i(1, 999)    # F1, inclusive min/max
@export var max_mp_range: Vector2i = Vector2i(0, 99)
@export var attack_range: Vector2i = Vector2i(1, 99)
@export var defense_range: Vector2i = Vector2i(0, 99)
@export var speed_range: Vector2i = Vector2i(1, 99)
@export var power_range: Vector2i = Vector2i(1, 100)     # F3/F4
@export var min_move_cost: int = 0                       # Content Data Rule 8: non-negative, no upper bound
static func load_or_default(path: String) -> StatsConfig

## src/battle/stats/stats_validators.gd — pure; registered from ContentBootstrap with the config bound
class_name StatsValidators
static func validate_stat_block(config: StatsConfig, record: Resource) -> PackedStringArray
static func validate_move(config: StatsConfig, record: Resource) -> PackedStringArray

## src/battle/combatant.gd (Core, §0) — changes
var _hp: int
var hp: int:
	get: return _hp
	set(_v): push_error("hp is written only via _apply_hp or restore_vitals (ADR-0007 §2)")
func _apply_hp(new_hp: int) -> void          # DamageResolver's Apply step only
func restore_vitals(new_hp: int, new_mp: int) -> void   # §2's allowlisted non-resolution writers only
# take_damage() / heal() removed

## Additions elsewhere (Feature)
# FactionRule:   func register_resolution_hooks(_hooks: ResolutionHooks) -> void   # base: no-op; void, no return needed
# BattleOutcome: var records: Array[ResolutionRecord]; var result: ResolutionRecord.Result
# BattleCore:    _init(squad, enemies, rng = null, faction_rule = null, stats_config := StatsConfig.new())
```

### Implementation Guidelines
- `DamageResolver` **must** stay static and stateless: no member state, no `get_tree()`, no autoload, no `Time`, no global RNG. Every input arrives in the `ResolutionRequest`. The only exception is the registry's debug-only `_resolving_depth` counter (§3).
- Nothing in `src/battle/stats/` **may** reference `BattleCore`, `FactionRule`, `BattleOutcome`, `Move`, `SquadSpecials` or any other Feature type.
- Every `damage` or `heal` effect in a battle **must** go through `DamageResolver.resolve()`. No system may compute damage or heal amounts itself, or apply them to HP.
- `Combatant.hp` **must** stay a read-only property. Only the resolver's Apply step **may** call `_apply_hp()`, and only §2's allowlisted writers **may** call `restore_vitals()`.
- The resolver **must** use `BattleCore.rng`, and **must never** call the RNG for a heal, a skipped target or an invalid effect.
- Overrides **must** run after F7, in the order priority → `String(source_id)` → registration index, with the index compared explicitly. Each result **must** be clamped to `0 .. amount_cap`. Only an override may produce 0.
- F2 **must** floor with the `1e-6` epsilon.
- Every tuning number **must** come from `StatsConfig`, loaded only through `StatsConfig.load_or_default()`. Tests compute expected values from the config, and each formula test also runs with a non-default config.
- `ResolutionHooks` **must** be rebuilt in every `start_battle()` call: clear, built-ins, then the faction hook. It is never shared between battles or stored globally.
- Modifiers and overrides **must not** touch the registry or resolve anything from inside `applies()`, `flat_for()`, `pct_for()` or `override()`.
- A new damage modifier or override **must** be registered, never added as a branch inside the resolver. The resolver knows nothing about Defend, Viral Stunt or any faction.
- `_resolve_move()` **must** check `can_afford()` before spending MP, for every actor.
- A non-resolving move **must** change no state, carry exactly one record, be appended to `outcome_log`, and **must not** be emitted on `action_resolved`. Every emitted outcome **must** be `RESOLVED` (asserted at the emit site).
- `StatModifier.stat` **must** stay limited to `ATTACK`, `DEFENSE` and `SPEED`, and the resolver **must** ignore and report any other value.
- `src/data/` **must not** import `src/battle/stats/`. The range validators are registered from `ContentBootstrap` with the config bound.

## Alternatives Considered

### Alternative 1: Document as built, and amend the GDD to match the code
- **Description**: Keep `DamageCalculator` with its hardcoded Defend and Viral Stunt terms, keep `const` tuning, add no Override step, and change the GDD's Core Rules 9–11 to describe today's behaviour.
- **Pros**: No code change, so nothing can regress.
- **Cons**: Every future modifier (each quirk, the next two factions, every piece of equipment) becomes an edit to one shared function, which grows an `if` per rule and couples Core math to Feature rules. The GDD's central promise, "only a rule can make a hit show 0", has no mechanism. The constants stay out of reach of tuning.
- **Rejection Reason**: It moves the cost onto every later system, and Quirk State and Faction Rule Modifiers are the next things to build.

### Alternative 2: Extend `FactionRule` with `modify_amount()` and `override_amount()` virtuals
- **Description**: The resolver calls two new virtual methods on the battle's single `FactionRule`.
- **Pros**: The smallest change, and it fits the existing hook pattern.
- **Cons**: There is exactly one `FactionRule` per battle, but modifiers come from several sources at once (Defend, quirks on each combatant, equipment, combos). Each would have to be routed through the faction object, or the resolver would grow a second and third hook path. There's no priority ordering between sources.
- **Rejection Reason**: The GDD needs many sources with a defined order; one virtual on one object can't express that.

### Alternative 3: A global modifier registry (autoload)
- **Description**: A `StatModifiers` autoload that any system registers with.
- **Pros**: Reachable from everywhere, with no plumbing.
- **Cons**: Mutable shared state across battles and attempts (a modifier left over from the last fight), which the registered `mutable_autoload_singleton` stance forbids. Tests would have to reset a global.
- **Rejection Reason**: Contradicts the registry stance and Architecture Principle 4. The right lifetime is one battle attempt (§3).

### Alternative 4: Emit non-resolving outcomes on `action_resolved`
- **Description**: Report `unaffordable` and `no_target` outcomes through the same signal as resolved ones.
- **Pros**: One stream for every consumer.
- **Cons**: ADR-0006's replay turns every emitted outcome into a beat, so a `no_target` beat would animate an actor attacking nothing. ADR-0006 (Accepted) would need a new map row and a skip rule.
- **Rejection Reason**: Logging them without emitting meets TR-stats-004 for every reader of records and leaves the replay untouched.

## Consequences

### Positive
- Quirk State, Combos, Equipment and the next factions plug in by registering, with no edit to Core math.
- HP changes in a battle have exactly one path, enforced at runtime by the read-only property, so every change produces a record and a number.
- The GDD's tuning knobs become editable data.
- The resolver is a pure function, so every formula and ordering rule is unit-testable with a stub RNG.
- The Foundation catalog stops depending on Core constants, and `Combatant`'s layer is stated.

### Negative
- A code change to shipped, playtested battle code. Mitigated by writing the characterization tests first (Migration Step 0).
- `Combatant.take_damage()`/`heal()` disappear, `hp` stops accepting writes, and the HUD demo's debug knockout and two specials change.
- One more `FactionRule` method (10 instead of 9), which the retroactive Faction Rule Modifiers ADR must document.
- `Combatant` still carries Turn Battle's flags (§0), as accepted interim debt.
- `restore_vitals()` is a public method, so its caller list is guarded by the lint, not the compiler.

## Risks
- **The refactor changes a number.** *Mitigation*: Step 0's characterization tests pin today's outputs with seeded RNGs for every shipped move and stat block, and must pass unchanged after every step. A test that needs changing is a regression, not a test update.
- **The RNG draw order shifts** (a heal or a skipped target starts drawing, or a second RNG instance appears). *Mitigation*: a test asserts that `rng.state` after a mixed sequence equals today's (probed: state round-trips exactly), and that heals never draw. §6 pins `BattleCore.rng`.
- **F2 floating-point error** yields off-by-one effective stats. *Mitigation*: the `1e-6` epsilon, and the `100 × 1.15 → 115` test case.
- **Non-alphabetical or unstable override order** (`StringName <`, `sort_custom`). *Mitigation*: §3's explicit comparator, and a test with IDs whose internal order differs from alphabetical.
- **A modifier with side effects** breaks determinism. *Mitigation*: the registry's debug-only depth guard, and the Implementation Guideline.
- **The 50 µs budget** is missed once many quirks register. *Mitigation*: the release-build benchmark with 8 modifiers and 2 overrides; per-resolution cost is linear in registered entries (about 4.7 µs probed).
- **The lint allowlist rots.** *Mitigation*: each line in the allowlist file names the writer and the ADR section that permits it, and adding a line needs an ADR reference in review.

## GDD Requirements Addressed

| TR-ID | GDD System | Requirement | How This ADR Addresses It |
|-------|------------|-------------|--------------------------|
| TR-stats-001 | stats-damage-resolution.md | Core Rule 9, F2–F8: the fixed six-step pipeline; tuning constants injected; median under 50 µs | §1 (`DamageResolver.resolve`, one order for both types), §4 (`StatsConfig`, one loader), Validation Criteria benchmark |
| TR-stats-002 | stats-damage-resolution.md | F6: RNG always injected, never global; heals never draw | §1 step 5 and the shared `BattleCore.rng`, `ResolutionRequest.rng`, Implementation Guidelines |
| TR-stats-003 | stats-damage-resolution.md | Core Rule 9 steps 2 and 5; Edge Cases: overrides by ascending priority, then source ID | §3 (`ResolutionHooks`, the three entry types, the explicit comparator, per-attempt lifetime) |
| TR-stats-004 | stats-damage-resolution.md | Core Rule 10: only Apply writes HP. Core Rule 11: one record per resolution, including `unaffordable`/`no_target` | §2 (read-only `hp`, `_apply_hp`, `restore_vitals`, lint), §5 (`ResolutionRecord`; non-resolving outcomes carry one record and are log-only) |
| TR-stats-005 (partial) | stats-damage-resolution.md | F1 ranges and costs checked at content validation; modifiers on `max_hp`/`max_mp` rejected | §7 (validators via ADR-0004; the ban by type plus a runtime check). `Enemy.reward` ranges wait for the enemy-record migration |
| — (no TR) | stats-damage-resolution.md | Core Rule 7: an unowned effect type is an error that changes nothing | §1 step 1 (`INVALID_EFFECT`, at the adapter and in the resolver) |
| — (no TR) | stats-damage-resolution.md | Edge Cases: several targets resolve separately, each with its own roll; a knocked-out target is skipped with a record | §1 step 2, §6 (Family Meal per member) |
| — (no TR) | content-data-definitions.md | Rule 8: ranges owned by Stats are validated | §7 |

## Performance Implications
- **CPU**: About 4.7 µs per resolution in a rough 4.7.2 probe (8 modifiers, 2 overrides, one draw), against the 50 µs budget. A battle resolves at most a few dozen per command, and there's no per-frame cost: resolution happens only inside `submit_action()`.
- **Memory**: One `ResolutionHooks` per `BattleCore` with a few entries; one `ResolutionRecord` per effect, kept in `outcome_log` for the attempt (tens of small objects).
- **Load Time**: One small `.tres`, loaded once (cached). The validators add one call per character, enemy and move record inside the catalog's existing load budget.
- **Network**: None.

## Migration Plan
0. **Characterization tests first** (shared with ADR-0001's Migration Step 0; `tests/unit/battle/` doesn't exist yet). With seeded RNGs, pin:
   - `DamageCalculator.calculate_damage()` and `SquadSpecials.calculate_heal()` outputs, for every shipped move against the shipped stat blocks, with Defend and Viral Stunt included;
   - for whole battles, the HP and MP of every combatant after each `action_resolved` emission, and the `outcome_log` entries **whose `result` is `RESOLVED`** (all of today's entries);
   - `rng.state` at the end of each battle.

   These tests don't change in any later step.
1. Add `StatsConfig` (with the GDD's defaults and `load_or_default`), `DamageResolver`, `ResolutionRequest`/`Context`/`Record`, `ResolutionHooks` and the three base classes, with unit tests. `DamageResolver` reproduces `DamageCalculator` exactly when the `defend` and `viral_stunt` modifiers are registered.
2. Switch `BattleCore` to the resolver:
   - add the trailing `stats_config` parameter;
   - own one `ResolutionHooks` and rebuild it in `start_battle()` (clear, built-ins, then `faction_rule.register_resolution_hooks()`);
   - route `_apply_damage()` and both heal branches through `resolve()` with `BattleCore.rng`;
   - add `records` and `result` to `BattleOutcome`;
   - delete `DamageCalculator` and `SquadSpecials`' heal functions.

   Step 0 must pass unchanged.
3. Make `Combatant.hp` read-only, and replace `take_damage()`/`heal()` with `_apply_hp()` and `restore_vitals()`. Move `reset_for_battle()`, `ChapterFlow`'s restore and the HUD demo's knockout onto `restore_vitals()`. Add `tools/ci/lint_hp_writes.sh`, its allowlist and the `src/battle/stats/` layering grep to CI.
4. **The one intended reporting change.** `_resolve_move()` checks `can_afford()`, and non-resolving enemy actions become log-only `NO_TARGET`/`UNAFFORDABLE` outcomes, each with one record, where today they're skipped silently. Step 0 still passes: those entries aren't `RESOLVED`, and they change no state or RNG.
5. With ADR-0001's migration: register `StatsValidators` in `ContentBootstrap.run()` (the lines §7 names).

**On acceptance (follow-ups to other documents):**
- ADR-0001: Status line gains "amended by ADR-0007"; a Review History entry; an annotation at its "constants reference" passage.
- ADR-0004 §1: the registrant list gains the Stats validators line.
- `docs/architecture/control-manifest.md`: the ADR-0001 rule "Numeric ranges … are read from a constants reference owned by Stats & Damage Resolution" is rewritten, and ADR-0007's rules are added (regenerate the manifest).
- `docs/registry/architecture.yaml`:
  - Stats & Damage joins the consumers of `content_record_validation`;
  - new state stance `combatant_hp` (write access: the resolver's Apply plus §2's allowlisted restorers);
  - new contract `resolution_hooks`;
  - new forbidden pattern: direct `.hp` writes.
- GDDs: `turn-battle-system.md` (`DamageCalculator.calculate_damage()` → `DamageResolver.resolve()`; the Viral Stunt magnitude moves to `StatsConfig.vulnerable_pct`), and `faction-rule-modifiers.md` (the hook contract gains `register_resolution_hooks()`, making it 10 methods).

## Validation Criteria
- **Unit (resolver)**, with a stub RNG returning 1.0 and a seeded one:
  - each formula, F2–F8, against the GDD's worked examples, with the default config and with a non-default config;
  - F2: `100 × (1 + 0.15)` gives 115;
  - F7: a varied amount of 0.4 gives 1; only an override gives 0; an override returning 1200 is clamped to the cap;
  - two overrides with equal priority run in `String(source_id)` order, using IDs whose internal `StringName` order differs from alphabetical, and the later one decides; equal priority and ID fall back to registration order; `overridden` is true when an override returns the same value;
  - a heal never advances the RNG; a skipped (knocked-out) target, damage or heal, produces `skipped = true`, no HP change and no draw;
  - an unowned effect type string at the adapter, and an out-of-range `EffectType` int at the resolver, each produce `INVALID_EFFECT` and change nothing;
  - a `StatModifier` with an out-of-range `stat` is ignored and reported.
- **Unit (registry)**:
  - a duplicate (`source_id`, kind) replaces the earlier entry; `remove_source()` drops all of a source's entries;
  - a modifier that calls `add_*` or `remove_source()` during a resolution triggers the debug error and changes nothing;
  - after `start_battle(false)`, a source registered mid-battle is gone and each built-in is present exactly once.
- **Unit (`Combatant`)**: writing `hp` leaves it unchanged and logs the error; `restore_vitals()` clamps both values.
- **Characterization**: Step 0's tests pass unchanged after every migration step.
- **Integration**: in a battle where an enemy's compound turn targets a squad member knocked out by its own first action:
  - `outcome_log` gains one `NO_TARGET` outcome with exactly one record;
  - `action_resolved` never emitted it, and the replay controller's queue holds no entry for it;
  - no HP, MP, flag or RNG state changed;
  - once the queue drains, `get_display(c)` equals live values for every combatant (ADR-0006).
- **Content validation**: the catalog rejects an out-of-range `stat_block` value, a negative `Move` cost and an out-of-range `power` through the registered validators, and passes the shipped data.
- **Lint and layering**:
  - the HP-write lint fails on fixtures with `x.hp = 1`, `x.hp -= 1`, `x.set(&"hp", 1)`, a stray `_apply_hp(` and a non-allowlisted `restore_vitals(`, and passes on `src/`;
  - a grep finds no reference to `BattleCore`, `FactionRule`, `BattleOutcome`, `Move` or `SquadSpecials` in `src/battle/stats/`.
- **Performance**: a headless benchmark on a release-template (non-debug) build resolves 10,000 damage effects with 8 amount modifiers and 2 overrides registered; the median is under 50 µs (TR-stats-001).

## Related
- Depends on: `docs/architecture/adr-0001-content-data-storage-format.md` (Accepted; amended by §7, annotation only), `docs/architecture/adr-0004-content-boot-ordering.md` (Accepted; §1's registrant list gains a line).
- Interacts with:
  - `docs/architecture/adr-0006-battle-replay-ownership.md`: unchanged. The replay uses snapshots, every emitted outcome is `RESOLVED`, and non-resolving outcomes change no state and are never emitted;
  - `docs/architecture/adr-0002-game-state-scene-flow.md` §7: the Retry restore is an allowlisted `restore_vitals()` caller, and Retry rebuilds the hook registry through `start_battle(false)`.
- Design: `design/gdd/stats-damage-resolution.md`; `design/gdd/turn-battle-system.md`; `design/gdd/faction-rule-modifiers.md` (gains `register_resolution_hooks`); `design/gdd/content-data-definitions.md` Rule 8.
- Code: `src/battle/damage_calculator.gd`, `src/battle/squad/specials.gd`, `src/battle/combatant.gd`, `src/battle/battle_core.gd`, `src/battle/battle_outcome.gd`, `src/battle/factions/faction_rule.gd`, `src/chapters/chapter_flow.gd:160`, `src/battle/ui/battle_hud_demo.gd:85`.
- Upcoming: the retroactive Turn Battle System ADR (including whether Turn Battle's flags leave `Combatant`, §0) and Faction Rule Modifiers ADR; a Quirk State System ADR.
- **GDD open question raised:** F8's provisional "overkill and full-HP heals show the full amount" conflicts with ADR-0006's snapshot-delta numbers, which show the HP that actually moved. One of the two documents must change.

## Review History
- 2026-10-22 — **godot-specialist** (engine validation, probed on 4.7.2): CONCERNS, no blockers. HIGH: `StringName <` isn't alphabetical, and `sort_custom()` isn't stable. MEDIUM: F2 floating-point floor error; enums aren't runtime-checked; the underscore convention isn't enforced. LOW: the depth flag mutates an input; the typed-return rule doesn't apply to `void`; unused-parameter warnings; the shared RNG instance. All folded in: §3's explicit comparator and registration index; F2's `1e-6`; runtime enum checks; the read-only `hp` property; the depth counter stated as debug bookkeeping; Engine Compatibility reworded; `_ctx` parameters; §1 and §6 pin `BattleCore.rng`. The probe results are recorded in Engine Compatibility.
- 2026-10-22 — **technical-director** (TD-ADR): CONCERNS. BLOCKING:
  - (1) the registry lifetime under Retry: it is now rebuilt in `start_battle()`;
  - (2) `Combatant`'s layer: new §0 makes it a Core type, with Turn Battle's flags as interim debt and a layering grep;
  - (3) Migration Step 0 contradicted Step 4: Step 0 now pins `RESOLVED` entries and per-emission HP/MP, and Step 4 is declared the one intended reporting change.

  Recommended items, all folded in:
  - §5 invariants, and one record per non-resolving outcome;
  - affordability at resolution for every actor, under one name (`can_afford`);
  - `restore_vitals()` and the stronger lint;
  - the cascade follow-ups listed under the Migration Plan;
  - one `StatsConfig` loader, with bound validators and explicit range fields;
  - a trailing, defaulted `BattleCore.new()` parameter;
  - the explicit sort keys;
  - interface consistency (`applies(ctx)` with `ctx.subject`, the `effective_stat` context, an integer `flat_for`, where `INVALID_EFFECT` originates);
  - six added Validation Criteria.

  TD expects APPROVE with no further review round once these are applied.
