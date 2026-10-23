# ADR-0010: Turn Battle System — Synchronous RefCounted Core, Ordered Command Checks, Descriptor-Built Battles, Flee

## Status
Accepted

## Date
2026-10-22

## Last Verified
2026-10-22

## Decision Makers
User (autonomous mode — decisions logged in `production/session-logs/decision-log.md`), Claude (orchestrating session), reviewed by godot-specialist (engine validation, probed on 4.7.2) and technical-director (TD-ADR). Retroactive: `BattleCore` ships in `src/battle/` (MVP epic, Stories 001–004 and 006). This ADR records what stays, and decides the parts that the GDD and Game State require but the code doesn't do yet. Revision 2 folds in both reviews.

## Summary
Turn Battle's core loop shipped before any ADR. It is a `RefCounted` state machine that resolves a whole round synchronously. It has four signals, and `submit_action()` returns `null` when it rejects a command. Three Accepted ADRs (0002, 0006, 0007) now build on it.

Two requirements are still unmet:
- battles must be built from Game State's Encounter descriptor (TR-turnbattle-003/004);
- a battle must be able to end in **Fled**, Game State's third outcome, which the code can't express (TR-turnbattle-001..003).

Decided:
- **`BattleCore` stays as it is.** It remains a pure, synchronous `RefCounted` that never touches the scene tree. Its four signals and the shape of `BattleOutcome` stay as ADR-0006 and ADR-0007 consume them.
- **A command check.** A side-effect-free `check_command()` runs the command checks in one fixed order. It reports why a command is illegal, so the HUD can disable options, and `submit_action()` uses the same check.
- **A Flee mechanism.** It adds a FLEE command category, a FLED terminal state and a fifth signal, `battle_fled`, which the replay controller releases as an END-class marker (an additive amendment to ADR-0006, listed clause by clause in §5). The flee rules themselves stay provisional until the GDD designs them.
- **A `BattleFactory` in the Battle mode** turns an `EncounterDescriptor` plus the party into a `BattleCore`.
- **Outcome reporting.** Only the Battle mode reports Victory, Fled and Defeat to Game State, and only after the replay finishes.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scripting: `RefCounted`, typed signals, enums) |
| **Layer** | Feature |
| **Knowledge Risk** | LOW. No post-cutoff API is introduced, and the shipped `BattleCore` already runs on 4.7.2 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.7 typed-return override row), `deprecated-apis.md`, `current-best-practices.md` |
| **Post-Cutoff APIs Used** | None directly. 4.7's inherited typed return applies to `FactionRule` overrides. A missing `return` there is a hard parse error (probed, ADR-0011) |
| **Verification Required** | **Probed on 4.7.2 (godot-specialist, 2026-10-22):**<br>(1) Six mutually referencing `class_name` scripts (`CommandCheck` with `enum Reason`, `EnemyAction`, a rule base and subclass returning `Array[EnemyAction]`, `StatsConfig`) compile, with no cyclic-reference error. **PROBED**<br>(2) `failures` as `(1 << Reason.X)` bits gives `68` for NO_MP + BAD_TARGET, with `reason` = the first failure. **PROBED**<br>(3) Object default arguments (`stats_config := StatsConfig.new()`) are evaluated per call, not shared. **PROBED**<br>(4) Enum values appended at the end of `State`, `Category` and `Reason` change no stored integer, because the shipped code stores none. **Verified by inspection** |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001** (Content Data, **Accepted**): `Character`/`Enemy`/`Move` records, the EffectDescriptor adapter.<br>**ADR-0002** (Game State, **Accepted**): `EncounterDescriptor`, `BattleEntryPayload`, `report_battle_outcome(BattleResult)`, `report_results_done()`, Retry by snapshot. Amended additively in §7.<br>**ADR-0006** (Battle Replay Ownership, **Accepted**): presentation consumes `BattleCore` only through the controller. Amended additively in §5.<br>**ADR-0007** (Stats & Damage, **Accepted**): `DamageResolver`, `ResolutionHooks`, `StatsConfig`, `BattleOutcome.records/result`.<br>**ADR-0011** (Faction Rule Modifiers, **Accepted** 2026-10-22): `EnemyAction`, `FactionRuleRegistry`, `Combatant.record_id`, side-effect-free rule predicates |
| **Enables** | The Battle mode story under Game State; ADR-0001 Migration Step 3 (the battle factories read the catalog through `BattleFactory`); a future Quirk State System ADR (§7) |
| **Blocks** | The Battle mode story (Battle as a `GameMode` reporting to Game State); the command-menu rewrite that disables illegal options. **Any story that ships Flee to players** is additionally blocked on a Flee section in `turn-battle-system.md` and a new TR for it (§5) |
| **Ordering Note** | **Additive amendment to ADR-0006** (annotation only; the clauses are listed in §5): a fifth `BattleCore` signal, `battle_fled`, handled as an END-class marker, and a `FLEE` action role.<br>**Additive amendment to ADR-0002 §7** (annotation only): clearing the party's per-fight transients moves from the requester (`ChapterFlow._clear_squad_transients()`) to the Battle mode, through `BattleCore.clear_transients(party)`. That matches what ADR-0006 §5 step 2 already does. No existing signal, field or call order changes |

## Context

### Problem Statement
The MVP battle loop (`battle_core.gd`, 327 lines) was built test-first for a single standalone fight, and later for a chapter sequencer. Since then:
- **ADR-0002** made Battle a `GameMode`:
  - it is entered with an `EncounterDescriptor`;
  - it reports `VICTORY`, `FLED` or `DEFEAT`;
  - on Victory, it waits for the results screen before leaving (AC-12);
  - it rejects `FLED` when the descriptor's `can_flee` is false (AC-13).

  `BattleCore` has no flee and no notion of a descriptor.
- **ADR-0006** put a replay controller between `BattleCore`'s synchronous signals and everything the player sees. It made the Battle mode report the outcome after the replay, and it constrained itself not to change `BattleCore`'s signals or `BattleOutcome`'s fields.
- **ADR-0007** moved all HP math into `DamageResolver`, gave `BattleOutcome` resolution records, and required every emitted outcome to be `RESOLVED`.
- **The GDD** (reverse-documented) calls a rejected submission "a HUD-level 'this option is disabled'". But the only way to learn that a command is illegal today is to submit it, and get `null` plus a `push_error`.

The TR registry lists TR-turnbattle-001/002 with no ADR, and TR-turnbattle-003 as partial.

### Constraints
- **Retroactive.** The core loop works and is covered by playtests. Change only what a requirement needs.
- **ADR-0006 invariants.** Every `BattleCore` emission is queued and released in order. `BattleCore` gains no scene-tree dependency. The Battle mode never connects to `BattleCore`'s turn signals directly.
- **ADR-0007 invariants.** Only `DamageResolver` changes HP. Non-resolving outcomes are logged, never emitted. `Combatant` is a Core type, and Turn Battle's flags on it are accepted interim debt.
- **Design gaps.** The GDD has no flee rule. Quirk State/Combo's relationship to `SpecialEffect` is `INTENT UNKNOWN` (QQ-02).

### Requirements
- TR-turnbattle-001: a `RefCounted` state machine with no scene tree; presentation is signal-only.
- TR-turnbattle-002: ordered gates (MP, `move_allowed`, `specials_allowed`, target); a rejected submit returns `null` and changes nothing.
- TR-turnbattle-003: consume the Encounter descriptor; report Victory, Fled or Defeat, plus results-done.
- TR-turnbattle-004: catalog records, not hardcoded factories, through the EffectDescriptor adapter.
- TR-turnbattle-005: unchanged, owned by ADR-0006.

## Decision

**1. `BattleCore` stays a synchronous, scene-free state machine (TR-turnbattle-001).** It remains a `RefCounted` in `src/battle/battle_core.gd`.
- **Collaborators.** It receives every collaborator through `_init`: `squad`, `enemies`, `rng`, `faction_rule`, `stats_config`, and now `options: BattleOptions` (§5).
- **One call stack.** It resolves a squad command and, when the squad's turn ends, the whole enemy phase and round upkeep, in the same call stack.
- **Signals.** It keeps its four signals unchanged (`turn_started(Combatant)`, `action_resolved(BattleOutcome)`, `round_advanced(int)`, `battle_ended(bool)`) and adds one: `battle_fled()` (§5).
- **What it never does.** It never awaits, never reads time, and is never a `Node`.
- **Who reads it.** Presentation reads it only through `BattleReplayController` (ADR-0006).

The states are `SQUAD_TURN`, `ENEMY_TURN`, `WON`, `LOST` and the new `FLED`, appended at the end. `WON`, `LOST` and `FLED` are terminal until `start_battle()` runs again.

**2. Command checks: one function, one order, no side effects (TR-turnbattle-002).**

```gdscript
func check_command(move: Move, target: Combatant = null) -> CommandCheck
```

`CommandCheck` is a value object with four fields:
- `ok: bool`;
- `reason: Reason`, the first failure in table order;
- `failures: int`, one bit per failing gate;
- `resolved_target: Combatant`.

| Order | Reason | Failing when |
|---|---|---|
| 0 | `NOT_SQUAD_TURN` | `state != SQUAD_TURN` or no active combatant. **Short-circuits:** gates 1–5 are not evaluated (they need an actor) |
| 1 | `NO_MP` | the actor can't afford `move.mp_cost`: `Combatant.can_afford()` today, `DamageResolver.can_afford()` once ADR-0007 is implemented |
| 2 | `RULE_FORBIDS_MOVE` | `not faction_rule.move_allowed(actor, move)` |
| 3 | `SPECIALS_BANNED` | `move.category == SPECIAL and not faction_rule.specials_allowed(round_number)` |
| 4 | `FLEE_NOT_ALLOWED` | `move.category == FLEE and not options.can_flee` (§5) |
| 5 | `BAD_TARGET` | the target type doesn't resolve to a legal, living target |

- **Gate evaluation.** After gate 0, every gate is evaluated, so the HUD can show one reason and still know all of them. The rule predicates are side-effect-free and draw no RNG; that is a requirement of ADR-0011 §2.
- **No side effects.** `check_command()` changes nothing: no state, no RNG draw, no signal, no log line.
- **Submitting.** `submit_action(move, target)` calls `check_command()` first. On failure it returns `null`, changes nothing, and logs with `push_warning`. An illegal submit means the UI offered an option it should have disabled.
- **The order change.** The shipped code checks Specials before `move_allowed` and MP. Reordering changes only which reason is reported first, never whether a command is accepted, because every shipped predicate is side-effect-free (TD-verified). The characterization tests (ADR-0001 Migration Step 0) pin acceptance, not error text.

**3. Battles are built from the descriptor by `BattleFactory` (TR-turnbattle-003/004).** `BattleFactory` (`src/battle/battle_factory.gd`) is a static, pure Feature class. In production it is the only code that constructs a `BattleCore`:

```gdscript
static func build(payload: BattleEntryPayload, catalog: ContentCatalogService,
                  rules: FactionRuleRegistry, stats_config: StatsConfig,
                  config: TurnBattleConfig, rng: RandomNumberGenerator) -> BattleBuildResult
```

- **Enemies** come from the descriptor's `enemy_ids`, through `catalog.get_record(&"enemy", id)` and the EffectDescriptor adapter (ADR-0001). It builds one new `Combatant` per ID, in descriptor order, each with `record_id` set to that ID (ADR-0011 §5).
- **The squad** is `payload.party`: the requester's own `Combatant` instances, changed in place (ADR-0002 §7 carryover). The factory never copies them.
- **The rule:**
  1. the factory looks up the `Faction` record by `descriptor.faction_id`;
  2. it follows `rule_id` to the `FactionRuleData`;
  3. it calls `rules.create(faction, rule)` (ADR-0011 §4).

  An unknown faction, or a faction with no rule, is a build failure, not a neutral rule.
- **Options** come from the descriptor (`can_flee`) and from `TurnBattleConfig` (`flee_chance`), as described in §5.
- **Failure.** A missing record or an unknown faction returns a `BattleBuildResult` with errors. The Battle mode reports it as a swap failure, and ADR-0002's rollback returns to the Overworld. ADR-0002's descriptor validation should already have caught it.

**Interim path.** Until ADR-0001's enemy-record migration lands, ADR-0002 §8's `validate_enemy_ids_against_catalog = false` is in effect. `BattleFactory` then holds an interim table from enemy ID to factory, covering the IDs `ChapterMode` emits:

| Enemy ID | Interim factory |
|---|---|
| `enemy_clerk` | `BureaucratiaRule.make_clerk` |
| `enemy_supervisor` | `BureaucratiaRule.make_supervisor` |
| `enemy_security_drone` | `MegaCorpRule.make_security_drone` |
| `enemy_middle_manager` | `MegaCorpRule.make_middle_manager` |
| `enemy_ceo` | `MegaCorpRule.make_ceo` |

The rule comes from ADR-0011's registry using the in-code defaults that `FactionRules.register_all()` exposes during the interim. The table and the flag are deleted together.

**RNG on Retry.** The Battle mode creates the RNG once per Battle mode instance, and does **not** restore it on Retry. A retried fight draws fresh variance, while HP/MP, the enemies and the round restart from the snapshot (ADR-0002 §7). This **preserves the as-built behaviour**: `ChapterFlow` shares one RNG across retries. It is a provisional default, pending the game-state GDD's Open Question 2. If design wants identical rolls, the snapshot adds `rng.state` and nothing else changes.

**4. The enemy phase consumes typed actions.**
- `faction_rule.choose_enemy_action(enemy, living_squad, round_number, rng)` returns `Array[EnemyAction]` (ADR-0011 §3), replacing today's untyped `Array` of `Dictionary`.
- `BattleCore` resolves the actions in order.
- An action whose target was knocked out earlier in the same turn produces a logged, non-emitted `NO_TARGET` outcome (ADR-0007 §5), replacing today's silent `continue`.
- A `null` target is legal for `SELF`-target moves.

**5. Flee, and the end-of-battle handshake (TR-turnbattle-003).**

*Normative mechanism:*
- `Move.Category.FLEE` and `BattleCore.State.FLED` are appended. `Move.make_flee()` builds a 0-MP, `SELF`-target move.
- **`BattleOptions`** (`RefCounted`) has `can_flee: bool` and `flee_chance: float`. `flee_chance` comes from `TurnBattleConfig` (`data/config/turn_battle_config.tres`), a Turn Battle project config, not Stats' `StatsConfig`.
- Flee is gated by `check_command()` gate 4, and is resolved at one point in `_resolve_move()`.
- **On success**, `BattleCore` does three things in order:
  1. emits one `action_resolved` outcome: `category = FLEE`, `target = null`, `hp_delta = 0`, no resolution records, `fled = true`;
  2. sets `state = FLED`;
  3. emits **`battle_fled()`**.
- **On failure**, it emits the same outcome shape with `fled = false`, and the turn passes as it would after any other command.
- **Records.** A flee outcome is `RESOLVED` with zero records. Defend is the precedent: it is a RESOLVED outcome that changes no HP (ADR-0007 §5).
- **Why a fifth signal and not `battle_ended(won)`.** `battle_ended(bool)` can't carry three results, and changing its argument type would edit a signal ADR-0006 consumes.

*Provisional rules, pending a Flee section in the GDD (and a TR):*
- any living squad member may choose Flee on their turn;
- one roll, at `flee_chance`, default **1.0**, which means no RNG draw;
- a failure costs that member's turn;
- boss fights forbid flight only through the descriptor's `can_flee = false`.

**Flagged for design:** MegaCorp's `move_allowed()` returns `mp > 0 or ATTACK`, so a suspended member (0 MP) gets `RULE_FORBIDS_MOVE` on Flee, just as on Defend. Whether that is intended, or whether FLEE should be exempt from rule legality, is a design ruling. Until then the check stays uniform: the rule is consulted for every command.

*ADR-0006 amendment (annotation only, additive). FLED is an **END-class marker**:*

| ADR-0006 clause | Change |
|---|---|
| §1 / §8 | The controller connects to **five** `BattleCore` signals, and `dispose()` disconnects all five |
| §2 | The queue gains a `FLED` marker kind. Every emission takes a snapshot, so `battle_fled` takes an END snapshot. A FLED marker arriving while IDLE is released at once, like END |
| §3 | The signal table gains `battle_fled_after_replay()` |
| §4 step 4 | "A TURN or END marker ends the replay" becomes "a TURN, END or FLED marker". Before releasing it, the controller clears the latch and emits `replay_finished` |
| §5 "End of the fight" | Fled has no Victory or Defeat light and no `victory_hold`/`defeat_hold`. The Battle mode reports at once. A flee beat or hold is a presentation GDD follow-up |
| §7 | `BeatPlan.ActionRole` gains `FLEE`. Its required fallback animation is `idle`, and a move-specific `flee` animation plays when the sprite set has one. The `windup` callable answers for the `FLEE` role like any other role, returning the fallback's wind-up |
| Registry | `battle_replay_gating.signal_signature` gains `battle_fled_after_replay()`; `direct_battlecore_turn_signal_listening` gains `battle_fled` |

**Reporting.** Only the Battle mode reports to Game State, and only from the controller's markers:
- **Victory.** On `battle_ended_after_replay(true)`, the Battle mode follows ADR-0006 §5's end-of-fight order: the Victory light, then `victory_hold` on mode time. Then:
  1. `machine.report_battle_outcome(VICTORY)`;
  2. the results screen opens;
  3. when the player dismisses it, `machine.report_results_done()`. Game State waits for that call (AC-12).
- **Fled.** `battle_fled_after_replay()` → `machine.report_battle_outcome(FLED)`. Game State still rejects it when `can_flee` was false (AC-13), which can't happen when gate 4 is honoured.
- **Defeat.** `battle_ended_after_replay(false)` → the Defeat light and `defeat_hold` (ADR-0006 §5), then `machine.report_battle_outcome(DEFEAT)`.

**6. Retry and lifetime are ADR-0002/0006's, unchanged.**
- Under Game State, the Battle mode keeps one `BattleCore` for its whole life.
- It calls `start_battle(false)` on entry and after every Retry restore.
- It never calls `start_battle()` with its default argument, and never calls `retry_battle()`. Both remain, but are documented as harness-only.

**7. Per-fight transients stay on `Combatant` (interim), with named writers.**

`is_defending`, `is_stunned` and `vulnerable_rounds_left` stay where ADR-0007 §0 left them, as accepted interim debt.

**Do they move to a Turn Battle side-table now (ADR-0007 §0's question)?** No. Revisit in the Quirk State System ADR, which is blocked on QQ-02.

**Writers.** These are the only code that writes the flags:

| Writer | What it writes |
|---|---|
| `BattleCore` | Sets `is_defending` on Defend. Clears `is_defending` as its owner's turn begins (squad and enemies), and clears `is_stunned` as a stunned **enemy's** turn is skipped. Ticks `vulnerable_rounds_left` in round upkeep. |
| `SquadSpecials.apply_stun()` / `apply_vulnerable()` | Called from `BattleCore._resolve_move()`. |
| `Combatant.reset_for_battle()` | Unchanged, on the enemies and on a full reset. |
| `BattleCore.clear_transients(party: Array[Combatant])` | **New**, static, Feature-side. The Battle mode calls it on the party before `start_battle(false)` (ADR-0006 §5 step 2). It replaces `ChapterFlow._clear_squad_transients()`, which is deleted with ADR-0002 §8's interim. This is the ADR-0002 §7 amendment named in the Ordering Note. |

Squad members are never stunned today: Karen's stun targets enemies. If a future effect stuns the squad, it must add the squad-side skip-and-clear to `BattleCore` and to this list.

**8. Specials stay a closed enum until QQ-02 is answered.**
- `Move.SpecialEffect` stays closed, and is dispatched by `match` in `_resolve_move()`.
- ADR-0001's migration maps each EffectDescriptor `type` that Turn Battle registers (`register_known_effect_types(&"turn_battle", …)`, ADR-0004) to one category/effect pair.
- A new effect type means a new enum value, a new `match` arm, a new registration and a test.

### Architecture Diagram

```
 Game State ─ request_transition(BATTLE, BattleEntryPayload) ─► Battle mode (GameMode, Feature)
                                                                 │
   BattleFactory.build(payload, catalog, rule registry, StatsConfig, TurnBattleConfig, rng)
     ├─ enemies: catalog enemy records → Combatant (record_id)   (interim: ID → code-factory table)
     ├─ squad:   payload.party (same instances)
     ├─ rule:    faction record → rule record → FactionRuleRegistry.create(faction, rule)   (ADR-0011)
     └─ options: can_flee (descriptor), flee_chance (TurnBattleConfig)
                                                                 ▼
   BattleCore (RefCounted, synchronous)                      BattleReplayController (ADR-0006)
     check_command(move, target) → CommandCheck   (HUD disables options; no side effects)
     submit_action(move, target)  ─ check → resolve (DamageResolver, ADR-0007) ─┐
       signals: turn_started · action_resolved · round_advanced                │ queue + snapshots
                battle_ended(won) · battle_fled()   ◄── new (END-class) ──────►│
                                                                               ▼
                         *_after_replay markers ─► Battle mode ─► machine.report_battle_outcome(
                              VICTORY (after light + victory_hold) → results screen → report_results_done()
                              FLED    (at once)
                              DEFEAT  (after light + defeat_hold) → Defeat Prompt (Game State)
```

### Key Interfaces

```gdscript
## src/battle/battle_core.gd (changes only)
enum State { SQUAD_TURN, ENEMY_TURN, WON, LOST, FLED }          # FLED appended
signal battle_fled()                                             # new; END-class marker in ADR-0006
func _init(squad: Array[Combatant], enemies: Array[Combatant], rng: RandomNumberGenerator = null,
           faction_rule: FactionRule = null, stats_config := StatsConfig.new(),
           options: BattleOptions = null) -> void                 # null → BattleOptions.new() (can_flee false)
func check_command(move: Move, target: Combatant = null) -> CommandCheck   # pure query
func submit_action(move: Move, target: Combatant = null) -> BattleOutcome   # null on a failed check
static func clear_transients(party: Array[Combatant]) -> void    # Battle mode, before start_battle(false)
func start_battle(reset_squad: bool = true) -> void      # under Game State: always false
func retry_battle() -> void                              # harness only

## src/battle/command_check.gd
class_name CommandCheck extends RefCounted
enum Reason { NONE, NOT_SQUAD_TURN, NO_MP, RULE_FORBIDS_MOVE, SPECIALS_BANNED, FLEE_NOT_ALLOWED, BAD_TARGET }
var ok: bool
var reason: Reason            # first failing gate in table order; NONE when ok
var failures: int             # bit (1 << Reason) per failing gate
var resolved_target: Combatant

## src/battle/battle_options.gd
class_name BattleOptions extends RefCounted
var can_flee: bool = false
var flee_chance: float = 1.0

## src/battle/turn_battle_config.gd — project config, data/config/turn_battle_config.tres
class_name TurnBattleConfig extends Resource
@export var flee_chance: float = 1.0      # provisional until the GDD's Flee section

## src/battle/move.gd (changes only)
enum Category { ATTACK, DEFEND, SPECIAL, FLEE }          # FLEE appended
static func make_flee() -> Move

## src/battle/battle_outcome.gd (changes only)
var fled: bool                # meaningful only when category == FLEE

## src/battle/battle_factory.gd — the production construction path
class_name BattleFactory
static func build(payload: BattleEntryPayload, catalog: ContentCatalogService, rules: FactionRuleRegistry,
                  stats_config: StatsConfig, config: TurnBattleConfig,
                  rng: RandomNumberGenerator) -> BattleBuildResult
class_name BattleBuildResult extends RefCounted
var core: BattleCore          # null on failure
var errors: PackedStringArray

## Amendments (annotation only)
# ADR-0006: five BattleCore signals; FLED marker = END-class; battle_fled_after_replay(); ActionRole.FLEE → idle
# ADR-0002 §7: the party's transients are cleared by the Battle mode via BattleCore.clear_transients()
```

### Implementation Guidelines
- `BattleCore` **must not** extend `Node`, reference the scene tree, await, or read time. Every collaborator **must** come through `_init`.
- `check_command()` **must** have no side effects: no state change, RNG draw, signal or log. Gate 0 **must** short-circuit. The command menu **must** call `check_command()` to enable or disable options.
- Under Game State, a `BattleCore` **must** be built only by `BattleFactory.build()`. Test and harness code may construct it directly.
- Only the Battle mode **may** call `report_battle_outcome()` / `report_results_done()`, and only from `BattleReplayController`'s `*_after_replay` signals, following ADR-0006 §5's end-of-fight order.
- New enum values **must** be appended, never inserted.
- The transient flags **must** be written only by the writers listed in §7.
- `FactionRule.choose_enemy_action()` **must** return `Array[EnemyAction]`. `BattleCore` **must not** branch on the rule's subclass (TR-factionrules-001).
- Tests live in `tests/unit/battle/`. The characterization suite (ADR-0001 Migration Step 0) runs first and stays green through every migration step.

## Alternatives Considered

### Alternative 1: Document as built (no Flee, no `check_command`)
- **Description**: Record the shipped loop only. Leave Fled and option-disabling to the Battle mode.
- **Pros**: No code change to a working system.
- **Cons**:
  - Fled couldn't come from the battle. It would be invented outside, bypassing the replay.
  - Disabling options would mean re-implementing the gates in the HUD, where they would drift.
- **Rejection Reason**: Leaves TR-turnbattle-002/003 unmet.

### Alternative 2: Change `battle_ended(won: bool)` to `battle_ended(result: Result)`
- **Description**: One end signal carrying a three-value enum.
- **Pros**: One end marker; cleaner long-term.
- **Cons**: Changes a signal that ADR-0006 (Accepted) consumes, along with its `battle_ended_after_replay(won)` signature and every harness that connects to it.
- **Rejection Reason**: A fifth signal treated as an END-class marker gives the same behaviour additively. Revisit if a fourth end state appears.

### Alternative 3: Flee resolved by the Battle mode, outside `BattleCore`
- **Description**: The command menu's Flee asks Game State directly.
- **Pros**: No `BattleCore` change.
- **Cons**:
  - A flee would skip the replay queue: if enemy beats were still playing, the battle would leave mid-replay.
  - The flee would be missing from the outcome log.
  - It would bypass `check_command()`, so the faction rule and `can_flee` gating could be skipped.
- **Rejection Reason**: Every command goes through `BattleCore` and the replay.

### Alternative 4: Asynchronous `BattleCore` (await between actions)
- **Description**: `BattleCore` waits for presentation between actions.
- **Pros**: No replay queue.
- **Cons**: Couples logic timing to presentation, and breaks headless tests.
- **Rejection Reason**: Already rejected by ADR-0006.

## Consequences

### Positive
- The HUD disables illegal commands with a reason, and the same function guards submission.
- All three of Game State's outcomes come from the battle and pass through the replay.
- There is one production path from descriptor to `BattleCore`. ADR-0001's migration lands there too.
- TR-turnbattle-001/002 move from "gap" to covered. TR-turnbattle-003 moves from partial to covered (the mechanism; the Flee design is still pending).

### Negative
- Two additive amendments: ADR-0006 (a fifth, END-class marker; seven clauses annotated) and ADR-0002 §7 (who clears transients).
- Flee rules stay provisional, and a story that ships Flee to players waits on the GDD.
- The transient flags stay on a Core type until the Quirk State ADR.

## Risks
- **The command menu forgets `check_command()`.** *Mitigation*: `submit_action()` still refuses the command and logs a warning. A HUD test asserts every disabled option's reason.
- **Fresh RNG on Retry is a design call.** *Mitigation*: it preserves the as-built behaviour, the snapshot can add `rng.state` later with no API change, and it is flagged to Open Question 2.
- **The flee design arrives with different rules** (per-member chance, speed-based). *Mitigation*: the chance lives in one config value, read in one place, and a formula can replace it there.
- **MegaCorp suspension blocks Flee.** *Mitigation*: flagged for a design ruling (§5). The check stays uniform until then.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| turn-battle-system.md | TR-turnbattle-001: `RefCounted` state machine, no scene tree; presentation signal-only, never polls | §1 (kept); ADR-0006 for presentation |
| turn-battle-system.md | TR-turnbattle-002: ordered gates; a rejected submit returns `null` and changes nothing | §2 `check_command()` and `submit_action()` |
| turn-battle-system.md | MP gating, "intended as a HUD-level 'this option is disabled'" | §2 `CommandCheck.reason` / `failures` |
| turn-battle-system.md | TR-turnbattle-003: consumes the Encounter descriptor; reports Victory, Fled or Defeat plus results-done | §3 `BattleFactory`; §5 the Flee mechanism and reporting |
| turn-battle-system.md | TR-turnbattle-004: factories replaced by records through the EffectDescriptor adapter | §3 (the production path), §8 (vocabulary) |
| game-state-scene-flow.md | Rule 7 / AC-12 / AC-13: Victory after results; Fled; Fled rejected when `can_flee` is false | §5 |
| turn-battle-system.md | Edge case: a compound enemy turn whose target was already knocked out | §4 (`NO_TARGET`, logged, per ADR-0007 §5) |

## Performance Implications
- **CPU**: `check_command()` runs once per menu option each time a turn opens: a handful of calls, microseconds each. No per-frame work.
- **Memory**: one `CommandCheck` per query, and one `BattleOptions` per battle.
- **Load Time**: `BattleFactory`'s catalog lookups run during the SWAP phase, bounded by the enemy count.

## Migration Plan
1. **Step 0 (ADR-0001):** characterization tests for `BattleCore` in `tests/unit/battle/`. They cover acceptance of each command, the outcome log, signal order and carryover.
2. **`CommandCheck` + `check_command()`**, with `submit_action()` rewired through it.
3. **The Flee mechanism:** `BattleOptions`, `TurnBattleConfig`, `Move.Category.FLEE`, `State.FLED`, `battle_fled`, `make_flee()`, `BattleOutcome.fled`, and the ADR-0006 controller amendment with its tests. Not exposed in the shipped command menu until the GDD has a Flee section.
4. **`BattleCore.clear_transients()`**, used by `ChapterFlow` until it is deleted, then by the Battle mode.
5. **With ADR-0011's Migration Step 2:** `Array[EnemyAction]`.
6. **With ADR-0011's Step 3 and the Battle mode story** (Game State implementation): `BattleFactory` (the interim ID table, rules from the registry), reporting from the controller markers, and the results screen calling `report_results_done()`.
7. **With ADR-0001 Migration Step 3:** `BattleFactory` reads enemy records, and the interim table and flag are deleted.

## Validation Criteria
- **Each gate in isolation.** `check_command()` returns the documented `reason` for each gate, and the full `failures` set when several gate fail. When it isn't the squad's turn, it returns `NOT_SQUAD_TURN` without evaluating any other gate. Calling it changes no state and draws no RNG: assert `rng.state` is unchanged.
- **Rejected submit.** A rejected `submit_action()` returns `null`, emits nothing, and leaves `outcome_log` unchanged.
- **Flee.**
  - With `can_flee = false`, Flee is rejected at `check_command()`.
  - With `can_flee = true` and `flee_chance = 1.0`, one `FLEE` outcome is emitted, then `battle_fled`. The state is `FLED`, and no RNG is drawn.
- **Through the controller:**
  - `battle_fled_after_replay` fires only after every earlier beat;
  - `replay_finished` precedes it, and the latch is cleared;
  - the Battle mode then reports `FLED` once.
- **Victory.** `report_battle_outcome(VICTORY)` is called after the Victory light and `victory_hold`. `report_results_done()` is called only after the results screen is dismissed.
- **Factory failure.** `BattleFactory.build()` with an unknown `faction_id` returns errors and no core.

## Related
- **Depends on:**
  - `adr-0001-content-data-storage-format.md`;
  - `adr-0002-game-state-scene-flow.md` (amended additively, §7);
  - `adr-0006-battle-replay-ownership.md` (amended additively, §5);
  - `adr-0007-stats-damage-resolution.md`;
  - `adr-0011-faction-rule-modifiers.md` (Proposed; accept it first).
- **GDD follow-ups:**
  - `design/gdd/turn-battle-system.md` needs a Flee section, the gate-order note, and the MegaCorp-suspension ruling;
  - `design/gdd/game-state-scene-flow.md` Open Question 2 (RNG on Retry);
  - `design/gdd/sprite-camera-presentation.md` needs a flee beat and hold.

## Review History
| Date | Reviewer | Verdict | Notes |
|------|----------|---------|-------|
| 2026-10-22 | technical-director (TD-ADR) | CONCERNS → revised | **2 blocking, both fixed:**<br>- The ADR-0006 amendment was incomplete. Fixed: FLED is now an END-class marker, with seven clauses listed.<br>- The ADR said it amended nothing in ADR-0002, which contradicted ADR-0002 §7 on who clears transients. Fixed: declared as an additive amendment.<br>**Advisories folded in:**<br>- the full writer list, and a Feature-side static `clear_transients()`;<br>- the side-table question answered (no; revisit in the Quirk State ADR);<br>- flee rules marked provisional, with a Flee story blocked on the GDD;<br>- MegaCorp suspension vs Flee flagged for design;<br>- gate 0 short-circuits, with `Combatant.can_afford` used until ADR-0007 is implemented;<br>- an interim enemy ID table;<br>- `BattleFactory` sequenced after the ADR-0011 registry;<br>- RNG noted as preserving as-built behaviour;<br>- the Victory path follows ADR-0006 §5's holds;<br>- the Defend precedent cited;<br>- `is_boss` dropped from `BattleOptions`;<br>- `flee_chance` moved to `TurnBattleConfig`;<br>- the squad-stun statement corrected;<br>- the presentation flee beat flagged |
| 2026-10-22 | godot-specialist | APPROVE WITH NOTES | Probed cross-reference compilation, the typed-array override and its missing-return parse error, the `failures` bit maths, and per-call default arguments |
| 2026-10-22 | `/architecture-review` (`architecture-review-2026-10-22b.md`) | PASS (this ADR) | No conflicts. godot-specialist: PASS. **F7** (advisory): if `rng.state` is ever saved, store it as a string, since JSON numbers are floats. Flee-shipping stories stay blocked on a Flee section in `turn-battle-system.md` and its TR (§5) |
| 2026-10-22 | User | **Accepted** | Explicit instruction (order ADR-0013 → ADR-0008 → ADR-0009 → ADR-0011 → ADR-0010). Dependencies ADR-0001, 0002, 0006, 0007 and 0011 are Accepted. No story was Blocked on this ADR. Its additive amendments to ADR-0006 (`battle_fled` as an END-class marker, a `FLEE` action role) and ADR-0002 §7 (per-fight transient clearing moves to the Battle mode through `BattleCore.clear_transients(party)`) are annotated in their Status sections |
