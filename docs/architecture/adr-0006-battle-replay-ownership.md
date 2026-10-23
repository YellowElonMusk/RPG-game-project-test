# ADR-0006: Battle Replay Ownership — Gating Turn Battle's Outcome Log Behind Presentation

## Status
Accepted — amended by ADR-0010 (§5: a fifth `BattleCore` signal, `battle_fled`, handled as an END-class marker, and a `FLEE` action role; Accepted 2026-10-22, amendment in effect, annotation only)

## Date
2026-10-21 (revision 2: 2026-10-22; revision 3: 2026-10-22; revision 4: 2026-10-22)

## Last Verified
2026-10-22

## Decision Makers
User (autonomous mode — decisions logged in `production/session-logs/decision-log.md`), Claude (orchestrating session), reviewed by godot-specialist and technical-director (TD-ADR). Revision 2 applies creative-director ruling (3) of the 2026-10-22 `/design-review` of `design/gdd/sprite-camera-presentation.md` (MAJOR REVISION NEEDED): "Replay timing moves to ADR-0006 now."

> **Revision 2 (2026-10-22).** The fourth `/design-review` found this ADR contradicting the GDD's rule 9 in at least five places. It also found the Retry order wrong against ADR-0002 §7, the resync stale, and no API for gating on the reveal. Per the creative-director ruling, this ADR now owns the **whole controller contract**:
> - the state machine and signals (§3);
> - the call order on first entry, Retry and exit, with `start_battle(false)` and the resync order (§5);
> - the latch and cancel (§6, §8);
> - `advance()`'s event order and leftover `dt` (§4);
> - the outcome-to-animation map (§7);
> - `boss_combatant` (§5).
>
> The GDD's rule 9 keeps the player-facing guarantees and the `replay_time` formula, which this ADR implements. The automatic speed-up (`replay_cap`, `speed_cap`, `speed_auto_max`, `speed_max`) is **deferred** to a GDD Open Question (ruling 4) and is not in this contract. Superseded text from revision 1 is not kept. Its Review History entry records what changed.

> **Revision 3 (2026-10-22).** The fifth `/design-review` of the GDD tracked eight items to this ADR (its review log, entry 5). Two of them were defects:
> - **the displayed state went stale at turn start:** `BattleCore` clears `is_defending` and `is_stunned` as a turn begins, with no outcome emitted, so the HUD kept showing them (AC-14 failed);
> - **nothing signalled a Retry:** `resync()` changed the displayed state silently, so the HUD and sprites had no cue to reset.
>
> Revision 3 makes these changes:
> - snapshots at the TURN and END markers (§2);
> - a `display_resynced` signal, and the Retry display reset that hangs off it (§3, §5, §8);
> - a cancel at `transition_started(BATTLE, BATTLE)` as well as in SWAP;
> - the end-of-fight hold cancelled on every exit (§5);
> - clearing squad transients, plus a `resync()`, on first entry (§5);
> - the per-event timing tolerance (§4);
> - the knockout-keyed hold and the no-reactor hold (§7);
> - creative-director rulings 1–3 of that review for speed: knockouts are plain beats, "Speed up boss entrances" gives the takeover the plain-beat speed, there is a passive indicator state with refusal, and a click un-latches (§6);
> - the actor is never in its own reactions (§7);
> - a displayed round (§8).

## Summary
Turn Battle's `BattleCore` resolves a command and every enemy action after it synchronously, emitting each outcome, the round change, the next turn and the battle's end in one call stack. The Sprite & Camera Presentation GDD (rule 9) and ADR-0002 §7 need those results held and replayed beat by beat before anything downstream sees them.

Decided: `BattleReplayController` (`RefCounted`, `src/battle/`, owned by the Battle mode, never modifying `BattleCore`):
- queues every `BattleCore` signal in emission order, with a display snapshot after each one;
- turns each outcome into a **beat plan** (actor action, per-combatant reactions and HP changes, punch, protection);
- runs each beat on two clocks it owns (a scaled wind-up and an unscaled post-impact clock), advanced only by the Battle mode's mode-time `advance(delta)`;
- holds everything behind a **reveal gate** until Game State's transition has fully revealed the scene, and behind the boss takeover's **hold entry** when there is one;
- releases gated copies of the turn, round and end signals only after the beats ahead of them have played.

The player's one-level speed-up latch, cancellation on every exit path, and the Retry call order against ADR-0002 §7 are part of the same contract.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (signal orchestration between a `RefCounted` game-logic object and its scene-tree presentation layer) |
| **Layer** | Feature (the controller lives beside Turn Battle System in `src/battle/`; Core-layer presentation consumes its signals, never the reverse) |
| **Knowledge Risk** | LOW — no post-cutoff API is introduced. The only shipped precedent is `BattleCore` itself (`RefCounted` + typed signals); `GameStateMachine` (ADR-0002) and `PresentationDirector` (ADR-0005) use the same pattern but are not yet implemented |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `breaking-changes.md` (no signal/`RefCounted`/typed-collection row for 4.5–4.7); `deprecated-apis.md` (`connect()` string form and `yield()` rows do not apply: typed `signal.connect(callable)` only); `current-best-practices.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None beyond the project's gdUnit4 headless pattern. Typed `Dictionary[K, V]` is not in the engine reference, but it was **probed on 4.7.2** (compiles; review of revision 3), so `BeatPlan` uses `Dictionary[Combatant, …]` (§7, Key Interfaces), as ADR-0005 does with `Dictionary[StringName, FlashSourceDecl]`. Every override with a typed return ends in an explicit `return` (4.7 typed-return inheritance) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Game State & Scene Flow, Accepted 2026-10-22). The controller depends on: §2 (Battle mode is a `GameMode`); §4 (only the Overworld is ever detached, so the Battle mode's `_exit_tree()` means it is being freed); §5 (`ModeHost` disabled under the Menu freezes `advance()`); §6 (actions reach the Battle mode through `handle_action()`); §7 (Retry calls `restore_start_snapshot()` on the same instance during SWAP; the Battle → Battle row emits `transition_finished(BATTLE)` at the end of the retry flash); and Migration Step 2 (the Battle mode, not `ChapterFlow`, constructs and starts `BattleCore`) |
| **Enables** | ADR-0005 (Sprite & Camera Presentation): its `CharacterSprite`, `DioramaStage` and `PresentationConfig` consume and configure this controller, taking the clocks as injected `Callable`s; this controller never references Core presentation code. The GDD's rule 9 and rule 6 (`sprite-camera-presentation.md` revision 6) |
| **Blocks** | Any `/dev-story` for the Battle mode scene or `BattleHud` rewiring; acceptance of ADR-0005 (its sprite clock comes from §4 here) |
| **Ordering Note** | Does not supersede ADR-0002 or ADR-0005. It fills a mechanism gap both leave to "the Battle mode". ADR-0005 was moved from Depends On to Enables on 2026-10-22 (`architecture-review-2026-10-22.md`, Cross-ADR Conflicts): the dependency only ever ran one way in code, so the graph is now 0006 → 0002 and 0005 → 0006, and this ADR is Accepted before ADR-0005. **Hard prerequisite for implementation:** ADR-0002 Migration Step 2. Today `ChapterFlow._start_fight` constructs `BattleCore` and calls `start_battle()` before anyone can connect (`src/chapters/chapter_flow.gd:124-127`), and a loss builds a fresh `BattleCore` (`chapter_flow.gd:140`), so neither the gate nor a single connected controller is possible against today's code |

## Context

### Problem Statement
`BattleCore.submit_action()` (`src/battle/battle_core.gd:150`) resolves one action synchronously. Before it returns, it emits `action_resolved` once per outcome (line 243), then, in the same call stack, `round_advanced` (line 313) and `turn_started` (lines 183, 315) or `battle_ended` (lines 321, 325). `start_battle()` also emits `turn_started` synchronously (line 90). Between the last enemy outcome and `round_advanced`, the faction's `apply_round_upkeep()` (line 294) changes MP with no outcome emitted; MegaCorp bills every living squad member (`src/battle/factions/megacorp.gd:109`). A stun is cleared silently when the stunned enemy's turn is skipped (line 281).

Two listeners react at once today:
- `ChapterFlow._on_fight_ended()` (`src/chapters/chapter_flow.gd:130`) restores HP and starts the next or retried fight the instant `battle_ended` fires.
- `BattleHud` connects `turn_started`, `action_resolved` and `battle_ended` directly (`src/battle/ui/battle_hud.gd:67–70`), opens the command menu on `turn_started`, and reads `combatant.hp`, which is already the final value.

`BattleOutcome` (`src/battle/battle_outcome.gd`) carries one `target` and one summed `hp_delta`. Family Meal heals every living member of the side as **one** outcome with `target == null` and `hp_delta` = the side total (`battle_core.gd:227–229`). Stun and Viral Stunt have a target and `hp_delta == 0`. The outcome carries `category` and `move_name`, but no special-effect field.

Revision 1 of this ADR named the queue but left the beat's timing, the call order and the input rules to the GDD. The two documents then drifted in five places across two reviews, which is why the creative director moved the whole contract here.

### Constraints
- **ADR-0002:** `BattleCore` and `ChapterFlow` are `RefCounted` with no scene-tree dependency so they stay headlessly testable. The controller must keep that property and must not add scene-tree dependencies to `BattleCore`.
- **Turn Battle System is implemented and LOW risk.** This ADR must not change `BattleCore`'s signals or `BattleOutcome`'s fields.
- **Creative-director rulings** (`/design-review`, 2026-10-21 and 2026-10-22), as they bind this contract:
  - **Knockout wind-ups are plain beats** (fifth review, ruling 2). A knockout beat's hold is `max(ko_hold, the slump's landing time)`, always at 1×. In MVP no beat is protected. Future combo and rule-trigger protection (GDD Open Question 5b) protects a beat's landing hold, never its wind-up.
  - Holds are real time; only the wind-up and the takeover's clock scale.
  - **One player latch level.** Any press latches every remaining wind-up to `ff_mult`. The first-encounter boss takeover is the one protected entry. It plays at 1× unless the opt-in "Speed up boss entrances" setting is On, and then it takes the plain-beat speed, Faster battle animations included, with no press needed (ruling 1).
  - **A press that changes nothing is refused**, and the indicator has a passive state. A click on the latched indicator un-latches. `battle_speed_mult` is strictly below `ff_mult` (ruling 3).
  - The boss takeover plays in full on first encounter, with a short settle on Retry.
  - A press counts only if it begins after the full reveal.
  - The automatic speed-up is deferred.
- **Coding standards:** dependency injection over singletons; every public method unit-testable; tuning values in data.

### Requirements
- Hold `turn_started`, `round_advanced` and `battle_ended` and release each only after every outcome emitted before it has finished its beat.
- Hold everything until the scene is fully revealed, and hold the first turn behind the boss takeover.
- Let the HUD show HP, MP and status as they were at the current point of the replay, for every outcome shape: the party heal, zero-HP outcomes, and the MP upkeep that has no outcome.
- Give every beat one authoritative clock, so sprite frames, the hit-punch and beat-synced sound can't drift, at any speed and under the Menu.
- Map every outcome shape to an actor action and per-combatant reactions, with no move ever playing the wrong pose.
- Retry and every exit discard queued work with nothing played later, and leave the controller in sync with the restored state.
- Testable headlessly, with no wall-clock time spent per beat.

## Decision

### 1. Ownership and construction
`BattleReplayController` is a `RefCounted` in `src/battle/battle_replay_controller.gd`, beside the `BattleCore` it wraps. Its value types, `BeatPlan` and `CombatantDisplay`, sit beside it. The Battle mode (a `GameMode`, ADR-0002 §2) constructs **one controller per Battle-mode instance**, and the same instance survives every Retry. It passes in:
- **`battle: BattleCore`**: the controller connects to all four signals read-only and never calls a mutator;
- **`windup: Callable`**: `(plan: BeatPlan) -> float`, the plan's wind-up at 1× in seconds. The presentation side supplies it: it is the summed duration of the actor's action animation frames before that animation's boot-validated `impact_frame` (GDD Formulas, `replay_time`, `w_i`). It returns `-1.0` when the actor has no action animation at all, which only a debug build that skipped boot validation can reach;
- **`ko_landing: Callable`**: `(combatant: Combatant) -> float`, the time at 1× from the start of that combatant's `knockout` animation to its boot-validated `land_frame` (GDD `replay_time`, `k_i`). It returns `0.0` on the debug path;
- **`config: PresentationConfig`** (ADR-0005), for the knobs in §9.

**`BattleCore` lifetime.** The Battle mode constructs its `BattleCore` from the `BattleEntryPayload` (ADR-0002 §7) and keeps it for the mode's whole life, across every Retry. `BattleCore` is never rebuilt for a Retry, and `retry_battle()` is never called (it full-heals). The controller is constructed and connected **before** the first `start_battle(false)` call.

### 2. The queue
Entries are kept in arrival order. Six kinds:

| Entry | Enqueued by | Carries | Takes time |
|---|---|---|---|
| `GATE` | `enqueue_reveal_gate()` | nothing | No: blocks until `open_reveal_gate()` |
| `HOLD` | `enqueue_takeover(boss, kind)` | `HoldKind`, the boss `Combatant`, a duration | Yes |
| `OUTCOME` | `action_resolved(outcome)` | a `BeatPlan` (§7) | Yes |
| `ROUND` | `round_advanced(n)` | `n` and a display snapshot | No |
| `TURN` | `turn_started(c)` | `c` and a display snapshot | No |
| `END` | `battle_ended(won)` | `won` and a display snapshot | No |

**Display snapshots.** At **every** `BattleCore` emission (`action_resolved`, `round_advanced`, `turn_started` and `battle_ended`), the controller records a `CombatantDisplay` for **every** combatant in the battle, read at that emission:
- `hp` and `mp`;
- `is_defending`, `is_stunned` and `vulnerable_rounds_left`.

Each snapshot also records `round_number`. Each one is the exact state at its point in the replay:
- **OUTCOME:** `action_resolved` fires after its outcome is applied, so the snapshot is the state after that beat.
- **ROUND:** taken after the round's upkeep, so MegaCorp's billing and the round's status ticks show when the round marker is released, not before.
- **TURN:** taken after `BattleCore` has started the turn. It catches the changes a turn makes with no outcome emitted: a squad member's `is_defending` cleared as their turn begins (`battle_core.gd:260`), and, through the snapshots that follow, an enemy's `is_defending` and `is_stunned` cleared during the enemy phase (`battle_core.gd:280–282`). Revision 2 snapshotted only OUTCOME and ROUND, so the displayed Defend and stun went stale at turn start.
- **END:** the final state, so the displayed state is exact when the end-of-fight light plays.

The **previous snapshot** of an entry is the last one recorded before it: an earlier entry's, or the settled snapshot taken at construction and by `resync()`.

If an entry arrives while the controller is `IDLE` (§3), the queue is empty and the entry is a marker (ROUND, TURN, END), it is released immediately, inside the emitting call. This keeps the standalone debug harness, which has no gate, working with no `advance()` loop.

### 3. States and signals

| State | Meaning | Left by |
|---|---|---|
| `IDLE` | Nothing queued or in progress | An entry arriving: a marker is released at once; a GATE moves to `GATED`; a HOLD or OUTCOME moves to `PLAYING` |
| `GATED` | A GATE is at the head of the queue. `advance()` does nothing, no entry starts, and no press is accepted | `open_reveal_gate()` (to `PLAYING`, or `IDLE` if only markers follow, which are then released) |
| `PLAYING` | A HOLD or OUTCOME is in progress, or is queued and starts on the next `advance()` | The queue draining (to `IDLE`) or reaching a GATE (to `GATED`) |
| `DISPOSED` | `dispose()` ran. Every method is a no-op; queries return defaults | — |

`cancel_pending_replay()` returns any state except `DISPOSED` to `IDLE`.

**A replay** is one unbroken run of `PLAYING`: it starts when the first HOLD or OUTCOME entry starts, and ends when the controller releases the TURN or END marker behind it, or when the queue drains. `is_replaying()` is true exactly while the state is `PLAYING`.

Signals, all emitted synchronously from inside `advance()`, an emitting `BattleCore` call, `open_reveal_gate()` or `cancel_pending_replay()`:

| Signal | When |
|---|---|
| `replay_started()` | The first HOLD or OUTCOME of a replay starts, before its `hold_started`/`beat_started` |
| `replay_finished()` | The replay ends, **before** the TURN or END marker that ends it is released, so the replay indicator hides and the latch clears before the command menu opens |
| `replay_cancelled()` | `cancel_pending_replay()` discarded at least one entry or an entry in progress |
| `display_resynced()` | `resync()` replaced the displayed state with the live state. Listeners reset to it: the HUD clears every number and shows the new values, every `CharacterSprite` returns to `idle` (knockout poses included), the punch offset goes to 0, and the indicator hides |
| `latch_changed(latched: bool)` | The latch is set, cleared by `clear_latch()`, or cleared at the replay's end |
| `press_effective_changed(effective: bool)` | `is_press_effective()` (§6) changed. It is evaluated at the end of every `advance()`, and after every latch, settings or queue change |
| `hold_started(kind: HoldKind, boss: Combatant)` / `hold_finished(kind: HoldKind)` | A HOLD entry starts / ends |
| `beat_started(plan: BeatPlan)` | An OUTCOME starts; its wind-up clock is 0 |
| `beat_impact(plan: BeatPlan)` | The wind-up reaches the impact; the post-impact clock is 0 on this frame |
| `beat_finished(plan: BeatPlan)` | The beat ends. Displayed state becomes the entry's snapshot **before** this signal is emitted |
| `round_advanced_after_replay(n: int)` | A ROUND marker is released. Displayed state becomes its snapshot first |
| `turn_started_after_replay(c: Combatant)` | A TURN marker is released |
| `battle_ended_after_replay(won: bool)` | An END marker is released |

Every OUTCOME emits exactly `beat_started`, `beat_impact` and `beat_finished`, in that order, unless it is cancelled. Every HOLD emits `hold_started` and `hold_finished`.

### 4. The clock: `advance(delta)`
The controller has no `_process`. Only the Battle mode's `_process` calls `advance(delta)`, with its mode-time delta. `ModeHost` is disabled under the Menu (ADR-0002 §5), so `advance()` is not called and every clock below freezes for free. Each call runs these steps, in this order:

1. **Guard.** If the state is `DISPOSED` or `GATED`, return.
2. **Step.** `dt = clampf(delta, 0.0, dt_max)`.
3. **Advance the entry in progress**, if there is one:
   - **HOLD:** `hold_time += dt × hold_speed` (§6). When `hold_time ≥ duration − ε`, it finishes: emit `hold_finished`, pop.
   - **OUTCOME in its wind-up phase:** `windup_progress += dt × speed` (§6) and `elapsed += dt`. When `windup_progress ≥ w − ε`, impact: the post-impact clock is set to 0 and `beat_impact` is emitted.
   - **OUTCOME in its post-impact phase:** `post_impact_time += dt` and `elapsed += dt`, both unscaled. When `post_impact_time ≥ plan.hold − ε` **and** `elapsed ≥ beat_min − ε`, it finishes: displayed state becomes the entry's snapshot, emit `beat_finished`, pop. A plan with `hold = 0` (no reactors) finishes on the first `advance()` after its impact at which `elapsed` has reached `beat_min`. At most one event per call still holds.
4. **Release markers.** While the head of the queue is a ROUND, TURN or END marker, release it. Every marker first applies its snapshot to the displayed state:
   - a ROUND then emits;
   - a TURN or END first ends the replay, if one is running: clear the latch (emitting `latch_changed(false)` if it was set), then emit `replay_finished`. Then it emits its own gated signal.
5. **Start the next entry**, if nothing is in progress:
   - if the head is a GATE, the state becomes `GATED`;
   - if it is a HOLD or OUTCOME, it starts. If no replay is running, emit `replay_started` first. A HOLD sets `hold_time = 0` and emits `hold_started`. An OUTCOME sets `windup_progress = elapsed = 0`, enters its wind-up and emits `beat_started`; if its `w ≤ ε`, impact follows at once in the same call (`beat_impact`);
   - if the queue is empty, the state becomes `IDLE`, and a running replay ends with `replay_finished`.

**Leftover `dt` is dropped, never carried.** When a step crosses an event (impact, or an entry finishing), the remainder of `dt` is discarded. So:
- every clock starts at exactly 0 on the frame of the event that starts it;
- at most **one** timed entry finishes per call, and a slow frame can never skip a beat;
- markers cost no time, so the command menu opens on the same frame the last beat finishes;
- a newly started entry spends no time on its starting frame.

Each event (impact, an entry finishing) therefore lands on the first frame at or after its formula time. A test allows **one frame step per event**, so a span covering N events (a whole beat has two: impact and finish; a whole replay has two per beat) allows N steps. Revision 2 said "per beat", which a two-event beat can exceed (fifth review). `ε = 1e-6`.

**The beat's three clocks**, all read by presentation through queries, never re-derived:
- `get_windup_progress()`: seconds of 1× wind-up played. Presentation derives the actor's wind-up frame from it.
- `get_post_impact_time()`: unscaled seconds since `beat_impact`. Presentation derives the actor's follow-through frame, each reacting combatant's reaction frame, and the hit-punch's `t` from it. Audio Manager fires the hit sound on `beat_impact`.
- `get_hold_time()`: the HOLD's own clock in seconds. Presentation derives the takeover blend's `t_blend` and the boss's `intro` frame from it.

**The debug path.** When `windup` returned `-1.0`, the beat uses `w = beat_min − reaction_hold` at speed 1, whatever the latch or settings, so impact lands at that unscaled time.

### 5. Call order
**First entry** (the Battle mode's `setup()`, which runs during Game State's SWAP phase, before `mode_entered(BATTLE)`):
1. Build `BattleCore` from the payload (enemy roster from the descriptor, the party's own `Combatant` instances).
2. **Clear the squad's per-fight transients** on the party `Combatant`s: `is_defending`, `is_stunned` and `vulnerable_rounds_left`. `start_battle(false)` resets only the enemies, and the party instances carry over from the previous fight (`ChapterFlow` carries HP/MP between fights), so a Defend or debuff left over from the last fight would otherwise start this one.
3. If `descriptor.is_boss`, resolve **`boss_combatant`**: the one enemy whose `Combatant.is_boss` is true. None or more than one is a descriptor validation failure, so the swap fails and rolls back (ADR-0002 Implementation Guidelines).
4. Construct the controller.
5. `controller.enqueue_reveal_gate()`.
6. If it is a boss fight: `controller.enqueue_takeover(boss_combatant, HoldKind.TAKEOVER_FULL)`.
7. `battle.start_battle(false)`. Its synchronous `turn_started` is queued behind the gate (and the hold).
8. `controller.resync()`, so the displayed state starts from the live state after `start_battle(false)`, exactly as on Retry. It emits `display_resynced`.
9. Game State then calls `capture_start_snapshot()` (ADR-0002 §7). The handle holds the party's HP/MP, as `start_battle(false)` left them untouched.
10. On `transition_finished(BATTLE)`: `controller.open_reveal_gate()`. The takeover, or the first command menu, starts on the first fully revealed frame.
11. **The boss light.** The stage entered on `battle` (ADR-0005 §3: every battle stage does). On the controller's `hold_started(HoldKind.TAKEOVER_FULL)`, the **Battle mode** calls `stage.request_profile(&"boss_<faction>", blend_boss, func(): return controller.get_hold_time())`, so the takeover blend runs on the hold's own clock from the Battle light. The stage never sees the controller type; it gets a `Callable`.

**Retry.** The Defeat Prompt calls `choose_retry()`, and Game State runs the Battle → Battle row: OUT (the retry flash), SWAP, IN.
- **At the start of OUT**, on `transition_started(BATTLE, BATTLE)`, the Battle mode cancels: `controller.cancel_pending_replay()`, and it stops its own end-of-fight hold if one is running. Revision 2 cancelled only in SWAP, which let anything still queued play behind the retry flash.
- **In SWAP** it calls `restore_start_snapshot(handle)` on the same Battle-mode instance, which runs, in this order:
1. `controller.cancel_pending_replay()`, again and unconditionally. It is normally a no-op.
2. Restore the party's HP/MP from the handle and clear per-fight transients (`is_defending`, `is_stunned`, `vulnerable_rounds_left`).
3. The **Battle mode** (never the Director) requests the light through `stage.request_profile()` (ADR-0005 §3): `battle` for an ordinary fight, `boss_<faction>` (the takeover's end state) for a boss fight. It asks `GameStateMachine.is_transition_flash_capped()` (ADR-0002 amendment), which reports the `FlashGate` result for this transition's retry flash. If the flash is uncapped, the light is requested with blend 0, hidden behind it. If it is capped (refused by the gate, or Reduce Flashing On), the flash no longer hides the change, so the light is requested with `blend_defeat`, a blend and never a pop (GDD States and Transitions). The Director's `mode_entered(BATTLE)` on this same-mode row does **not** re-apply the entry profile (ADR-0005 §4), so this light survives.
4. `controller.enqueue_reveal_gate()`.
5. If it is a boss fight: `controller.enqueue_takeover(boss_combatant, HoldKind.TAKEOVER_SETTLE)`.
6. `battle.start_battle(false)`. This resets the enemies, round 1 and the outcome log, and queues `turn_started` behind the gate. **Never** `start_battle()` or `retry_battle()`: both full-heal the squad.
7. `controller.resync()`. It must come **after** `start_battle(false)`, because that call resets the enemies' HP. A resync before it would leave the displayed enemy HP at the defeated values. It emits **`display_resynced`**, and its listeners reset the battle's display behind the flash: the HUD clears every number and shows the restored values, every `CharacterSprite` returns to `idle` (knockout poses included), the punch offset goes to 0 and the indicator hides. Revision 2 had no such signal, so nothing told the presentation side that a Retry had happened.
8. On `transition_finished(BATTLE)` at the end of the Battle → Battle row's IN phase (the end of the retry flash): `controller.open_reveal_gate()`. No new Game State announcement is needed.

**Exit.** On `transition_started(from, to)` with `from == BATTLE` and `to != BATTLE` (Victory or Fled → Overworld, Retreat → Camp, Quit to Title, including from the Menu), at the start of OUT the Battle mode:
- calls `controller.cancel_pending_replay()`;
- stops its end-of-fight hold if one is running, so `report_battle_outcome()` is never called for a battle being left.

So nothing plays behind the wipe. From its `_exit_tree()` it calls `controller.dispose()`. The Battle mode is never detached (ADR-0002 §4 detaches only the Overworld), so `_exit_tree()` always means it is being freed.

**End of the fight.** On `battle_ended_after_replay(won)`, the Battle mode requests the Victory or Defeat light and counts `victory_hold` or `defeat_hold` on mode time, then calls `report_battle_outcome()` (ADR-0002). These holds are the Battle mode's, not the controller's:
- they are not part of a replay, and the latch can't shorten them;
- during them, `confirm`, `fast_forward` and `cancel` presses are consumed and do nothing;
- they are cancelled by any `transition_started` away from the current battle (above).

### 6. Speed, the latch and input

**One latch, one level.**
- **`request_latch() -> bool`** sets the latch and returns true only if the state is `PLAYING`, the latch is not already set, and `is_press_effective()` is true. Then it emits `latch_changed(true)`. Otherwise it changes nothing and returns false.
- **`clear_latch() -> bool`** clears the latch and returns true only if it was set **and** `is_press_effective()` is true, emitting `latch_changed(false)`. Otherwise it returns false.
- The end of a replay and `cancel_pending_replay()` also clear the latch, unconditionally, so every replay starts unlatched.
- A false return means the press changed nothing. The Battle mode then asks the UI Framework for the refusal feedback (GDD rule 9).

**Press effectiveness.** `is_press_effective() -> bool` is true iff some time remains, in the entry in progress or in the queue, whose speed depends on the latch:
- a remaining wind-up of an OUTCOME that is not on the debug path;
- a remaining `TAKEOVER_SETTLE` hold;
- a remaining `TAKEOVER_FULL` hold, if `speed_up_boss` is On.

Holds after impact never count, so a replay with only knockout holds left is not press-effective. Because `battle_speed_mult < ff_mult` (§9), a remaining plain wind-up is always press-effective, whatever the settings. The UI shows the indicator's passive state exactly while this is false, driven by `press_effective_changed`.

**Speeds.** `set_speed_settings(battle_speed_on: bool, speed_up_boss: bool)` is called on settings change. With `plain = max(latched ? ff_mult : 1, battle_speed_on ? battle_speed_mult : 1)`, each frame's speed is:

| Entry | Speed |
|---|---|
| Debug-path beat | 1 |
| Any beat, knockouts included | `plain` |
| `TAKEOVER_FULL` hold (the one protected entry) | `plain` if `speed_up_boss`; otherwise 1 |
| `TAKEOVER_SETTLE` hold | `plain` |

Speed scales only the wind-up and the HOLD clock. The post-impact clock is never scaled. A speed change partway through an entry applies from the next `advance()`. Its remaining wind-up or hold runs at the new speed, and the `beat_min` floor is checked against elapsed unscaled time, so a mid-entry change is always well defined.

**Durations.** `TAKEOVER_FULL` lasts `blend_boss + boss_hold`. `TAKEOVER_SETTLE` lasts `boss_retry_hold`: the takeover light is already in place behind the retry flash, and the boss holds the last frame of its `intro`.

**Input routing** (the Battle mode's `handle_action()`; ADR-0002 §6):
- **While `is_replaying()`:**
  - a `pressed` for `confirm` or `fast_forward` calls `request_latch()`;
  - a `pressed` for `cancel` calls `clear_latch()`;
  - a click on the replay indicator, which the UI Framework reports as an indicator click (not as `confirm`), calls `clear_latch()` if latched, and `request_latch()` otherwise.

  All of these are **consumed**, whatever the result: they are never buffered and never fall through to the command menu, or to the Esc-opens-the-Menu fallback in Input GDD Open Question 1, which applies only in Overworld and Camp. The Menu is opened only by the `menu` action. A false return asks for the refusal feedback.
- **While `GATED`, and during the end-of-fight hold (§5):** these presses are consumed and do nothing. A press counts only if it begins after the full reveal.
- **"Begins after."** The Input System emits exactly one `pressed` per physical press, at its start, with no key-repeat echoes (Input rule 2, AC-2). A `pressed` that arrives during a replay therefore began during it. The `confirm` that submitted the command was consumed by the command menu before the replay existed, and a held key produces no new `pressed`. No timestamp test is needed in the controller.

The menu-opening guard (presses within `input_guard` of a menu opening are blocked, with visible and audible feedback for a refused press) is the UI Framework's, not the controller's (GDD rule 9).

### 7. Outcome-to-animation map (`BeatPlan`)
At `action_resolved`, the controller builds a `BeatPlan` from the outcome, its snapshot and the previous snapshot. For each combatant, `Δ = after.hp − before.hp`.

**The actor's action.** `move_name` selects a move-specific animation where the actor's sprite set has one. This is a stopgap: `BattleOutcome` has no move ID, so outcomes are keyed by display name until ADR-0001's content migration gives moves IDs, after which this key changes and nothing else does. Otherwise the action falls back by category:

| `outcome.category` | Action role | Required fallback animation |
|---|---|---|
| `ATTACK` | `ATTACK` | `attack` |
| `SPECIAL` | `SPECIAL` | `attack` (a missing move-specific special logs one warning, GDD rule 10) |
| `DEFEND` | `DEFEND` | `defend` (**required** for every battle sprite set: Defend never plays `attack`) |

**Reactions**, for each combatant with `Δ ≠ 0`, plus `outcome.target` if it is not null, **except the actor**. The actor never reacts to its own action: if its own HP changed (Family Meal heals the healer too, `battle_core.gd:228`), it keeps its action pose. Its `Δ` still goes into `hp_changes`, so it still gets its number.

| Condition | Reaction | Number | Punch |
|---|---|---|---|
| `Δ < 0` and `after.hp == 0` | `KNOCKOUT` | `Δ` | yes, big |
| `Δ < 0` | `HIT` | `Δ` | yes |
| `Δ > 0` | `HEAL` | `+Δ` | no |
| `Δ == 0`, is the target, `category == ATTACK` | `HIT` (a blocked or zero-damage hit) | none | no |
| `Δ == 0`, is the target, otherwise (Stun, Viral Stunt) | `STATUS` | none | no |

So Family Meal plans a `HEAL` with its own number over **each** healed member, from the snapshots, and Stun and Viral Stunt get a `STATUS` reaction and never show "0". The HUD shows a new status tag from the displayed state once the beat finishes.

**Plan fields:**
- `actor`, `action_role` and `move_name`;
- `reactions` (Combatant → reaction, never the actor) and `hp_changes` (Combatant → `Δ`, only non-zero, the actor included);
- `punch`: true if any reaction is `HIT` or `KNOCKOUT` with `Δ < 0`;
- `big_punch`: true if `punch` and (any `KNOCKOUT`, or `actor == boss_combatant`);
- `knockout`: true if any reaction is `KNOCKOUT`;
- `protected`: always false in MVP. Open Question 5b adds one clause for combo and rule-trigger beats, and it protects only `hold`, never the wind-up's speed (§6);
- `hold`:
  - `0.0` if `reactions` is empty (Defend);
  - `max(ko_hold, max over the KNOCKOUT reactors of ko_landing.call(c))` if `knockout`;
  - `reaction_hold` otherwise;
- `windup_1x`: from `windup.call(plan)`;
- `outcome`: the original, for logging.

**What the presentation side does with a plan** (ADR-0005's `CharacterSprite`):
- On `beat_started`, the actor switches to its action animation at frame 0, interrupting whatever it was showing. An actor who reacted in the previous beat, or acts in two beats in a row (Bureaucratia's Defend-then-Attack), goes straight into the new wind-up. The return to `idle` applies only to combatants that are not in the new beat.
- On `beat_impact`, each reacting combatant switches to its reaction:
  - `HIT` → `hit`, `KNOCKOUT` → `knockout`;
  - `HEAL` → `heal`, optional, falling back to staying in its current pose;
  - `STATUS` → `status`, optional, falling back to `hit`.
  
  A number still showing over a reacting combatant is cleared on this frame.
- **Frames.** Between `beat_impact` and `beat_finished`, the actor's follow-through and every reaction take their frames from `get_post_impact_time()`. An animation that runs out holds its last frame.
- **After `beat_finished`:**
  - the actor returns to `idle`;
  - a `HIT`, `HEAL` or `STATUS` reactor plays the rest of its reaction on mode time, then returns to `idle`;
  - a `KNOCKOUT` reactor plays `knockout` to its last frame and holds it until the battle ends or is retried.
  
  Any of these is interrupted at once if the combatant is the actor or a reactor of the next beat. No beat-driven animation uses `AnimatedSprite3D`'s own playback (ADR-0005).

### 8. Displayed state, cancel, resync and teardown
- **`get_display(c) -> CombatantDisplay`** returns a copy of `c`'s values from the most recently **released** snapshot: an OUTCOME at its `beat_finished`, or a ROUND, TURN or END marker at its release. With nothing released since the last sync, it returns the settled snapshot. On every released TURN, and when the queue drains, the displayed values equal `c`'s live values for every combatant, by construction. `get_display_hp(c)` is shorthand for `get_display(c).hp`.
- **`get_display_round() -> int`** returns the `round_number` of the same released snapshot. The HUD reads the round only through it, never `BattleCore.round_number`, which is already the next round mid-replay.
- **`cancel_pending_replay()`** clears the queue, any entry in progress and the latch. It emits `replay_cancelled` if anything was discarded, and returns to `IDLE`. It emits no beat, hold or gated signal for a discarded entry. Displayed state is left as it was, which is stale until `resync()`; exit paths don't need a resync. `boss_combatant` is kept.
- **`resync()`** re-takes the settled snapshot from live `Combatant` state, makes it the displayed state, and emits **`display_resynced`**. GATE, HOLD and marker entries may be queued. A queued or in-progress OUTCOME is a programming error: `push_error`, and nothing changes.
- **`dispose()`** calls `cancel_pending_replay()`, disconnects from all four `BattleCore` signals, drops the `windup` and `ko_landing` callables and the `config` reference (so a lambda capturing the controller can't form a cycle) and enters `DISPOSED`. It is idempotent.

### 9. Configuration
The controller reads these `PresentationConfig` knobs (ADR-0005; values and ranges are in the GDD's Tuning Knobs):
- `dt_max`, `beat_min`;
- `reaction_hold`, `ko_hold`;
- `ff_mult`, `battle_speed_mult`;
- `blend_boss`, `boss_hold`, `boss_retry_hold`;
- `gate_stuck_warn_s` (debug only; default 2.0 s, range 1.0–5.0): how long the Battle mode waits in `GATED` before logging the soft-lock error (Risks).

`PresentationConfig` load validation (a boot content error, each comparison with `ε` tolerance in the passing direction) includes these rules for the controller:
- `battle_speed_mult ≤ ff_mult − 0.25`, so the latch always speeds a wind-up beyond Faster battle animations (ruling 3; revision 2 allowed equality, which made the latch a no-op);
- `reaction_hold ≤ beat_min − 0.10`;
- `reaction_hold ≤ ko_hold`;
- `dt_max < beat_min`;
- `boss_retry_hold ≤ blend_boss + boss_hold`.

### 10. Out of scope
- **Combo and rule-trigger protection and outcome grouping** (GDD Open Question 5b). When `BattleOutcome` gains them, `protected` gains one clause and grouping becomes one plan over several outcomes. Nothing else changes.
- **The automatic speed-up toward a per-replay cap** (deferred, GDD Open Question 16). If it returns, it is one more term in §6's plain-beat speed, computed once at `replay_started`.

### Architecture Diagram

```
 BattleCore (src/battle, RefCounted — unchanged; owned by the Battle mode, survives Retry)
   action_resolved · round_advanced · turn_started · battle_ended   (synchronous)
        │ read-only connect (before the first start_battle(false))
        ▼
 BattleReplayController (src/battle, RefCounted — one per Battle-mode instance)
   queue: [GATE | HOLD(kind, boss) | OUTCOME(BeatPlan, snapshot) | ROUND(n, snapshot) | TURN | END]
   state: IDLE · GATED · PLAYING · DISPOSED          latch: on/off (one level)
   advance(delta) ◄── Battle mode _process (mode time; frozen under the Menu)
     1 guard · 2 clamp dt_max · 3 step entry (≤ 1 finishes) · 4 release markers · 5 start next
        │ replay_started/finished/cancelled, latch_changed        │ gated markers, in order
        │ hold_started/finished, beat_started/impact/finished     ▼
        ▼                                            round_advanced_after_replay
 CharacterSprite / DioramaStage / Audio (ADR-0005)   turn_started_after_replay ──► BattleHud command menu
   frames from get_windup_progress(),                battle_ended_after_replay ──► Battle mode: end light,
   get_post_impact_time(), get_hold_time()                                         hold, report outcome
 BattleHud: get_display(c) · get_display_round() · indicator on is_replaying()/latch_changed/
           press_effective_changed · reset on display_resynced

 First entry: build BattleCore ─► clear squad transients ─► controller ─► enqueue_reveal_gate
              ─► [enqueue_takeover(FULL)] ─► start_battle(false) ─► resync (display_resynced)
              ─► … transition_finished(BATTLE) ─► open_reveal_gate
 Retry:  transition_started(BATTLE, BATTLE) ─► cancel + stop end hold
         (SWAP) cancel ─► restore HP/MP ─► light behind flash (blend if capped) ─► enqueue_reveal_gate
              ─► [enqueue_takeover(SETTLE)] ─► start_battle(false) ─► resync (display_resynced)
              ─► … transition_finished(BATTLE) ─► open_reveal_gate
 Exit:  transition_started(BATTLE → other) ─► cancel + stop end hold    Free: _exit_tree ─► dispose
```

### Key Interfaces

```gdscript
## src/battle/battle_replay_controller.gd
class_name BattleReplayController
extends RefCounted

enum State { IDLE, GATED, PLAYING, DISPOSED }
enum HoldKind { TAKEOVER_FULL, TAKEOVER_SETTLE }

signal replay_started()
signal replay_finished()
signal replay_cancelled()
signal display_resynced()
signal latch_changed(latched: bool)
signal press_effective_changed(effective: bool)
signal hold_started(kind: HoldKind, boss: Combatant)
signal hold_finished(kind: HoldKind)
signal beat_started(plan: BeatPlan)
signal beat_impact(plan: BeatPlan)
signal beat_finished(plan: BeatPlan)
signal round_advanced_after_replay(round_number: int)
signal turn_started_after_replay(combatant: Combatant)
signal battle_ended_after_replay(won: bool)

## windup(plan: BeatPlan) -> float: 1× wind-up seconds, or -1.0 if the actor has no action animation.
## ko_landing(combatant: Combatant) -> float: 1× seconds from knockout start to its land_frame.
func _init(battle: BattleCore = null, windup: Callable = Callable(), ko_landing: Callable = Callable(), config: PresentationConfig = null) -> void: ...   # defaults only so gdUnit4 spy()/mock() can construct it; the Battle mode always passes all four, and advance() asserts they are set

# Queue control (Battle mode only; order in Decision §5)
func enqueue_reveal_gate() -> void: ...
func open_reveal_gate() -> void: ...
func enqueue_takeover(boss: Combatant, kind: HoldKind) -> void: ...

# Clock (Battle mode _process only)
func advance(delta: float) -> void: ...

# Player input and settings (Battle mode only)
func request_latch() -> bool: ...                # false = the press changed nothing (refuse it)
func clear_latch() -> bool: ...                  # false = the press changed nothing (refuse it)
func set_speed_settings(battle_speed_on: bool, speed_up_boss: bool) -> void: ...

# Read-only queries
func get_state() -> State: ...
func is_replaying() -> bool: ...
func is_latched() -> bool: ...
func is_press_effective() -> bool: ...          # false = indicator passive (§6)
func get_current_plan() -> BeatPlan: ...        # null unless an OUTCOME is in progress
func get_windup_progress() -> float: ...        # 1× seconds of wind-up played
func get_post_impact_time() -> float: ...       # unscaled seconds since beat_impact; 0 before it
func get_hold_time() -> float: ...              # HOLD clock seconds; 0 unless a HOLD is in progress
func get_boss_combatant() -> Combatant: ...     # null outside a boss fight
func get_display(combatant: Combatant) -> CombatantDisplay: ...
func get_display_hp(combatant: Combatant) -> int: ...
func get_display_round() -> int: ...

# Lifecycle (Battle mode only)
func cancel_pending_replay() -> void: ...
func resync() -> void: ...                        # emits display_resynced
func dispose() -> void: ...

## src/battle/beat_plan.gd — immutable after construction
class_name BeatPlan extends RefCounted
enum ActionRole { ATTACK, SPECIAL, DEFEND }
enum Reaction { HIT, KNOCKOUT, HEAL, STATUS }
var outcome: BattleOutcome
var actor: Combatant
var action_role: ActionRole
var move_name: String
var reactions: Dictionary[Combatant, Reaction]   # never the actor (typed Dictionary compiles on 4.7.2, probed)
var hp_changes: Dictionary[Combatant, int]      # non-zero only; the actor included
var punch: bool
var big_punch: bool
var knockout: bool
var protected: bool            # always false in MVP (Open Question 5b)
var hold: float                # 0 (no reactors), max(ko_hold, landing) on a knockout, else reaction_hold
var windup_1x: float           # -1.0 = debug path

## src/battle/combatant_display.gd — a value copy
class_name CombatantDisplay extends RefCounted
var hp: int
var mp: int
var is_defending: bool
var is_stunned: bool
var vulnerable_rounds_left: int
```

### Implementation Guidelines
- `BattleCore` and `BattleOutcome` **must never** be edited to add presentation awareness.
- Under Game State, the Battle mode **must** own its `BattleCore` for its whole life, call only `start_battle(false)`, and **must never** call `start_battle()` with the default argument or `retry_battle()`.
- The controller **must** be constructed, and `enqueue_reveal_gate()` called, before every `start_battle(false)`. `enqueue_takeover()` **must** come after the gate and before `start_battle(false)`.
- The Battle mode **must** call `open_reveal_gate()` only from its `transition_finished(BATTLE)` handler.
- On first entry, the order **must** be: build → clear squad transients → controller → gate → takeover → `start_battle(false)` → `resync()`.
- On Retry, the Battle mode **must** cancel (and stop its end-of-fight hold) on `transition_started(BATTLE, BATTLE)`, and the SWAP order **must** be: cancel → restore → light → gate → takeover → `start_battle(false)` → `resync()`.
- Every listener that shows battle state (`BattleHud`, every `CharacterSprite`, the punch, the indicator) **must** reset to the displayed state on `display_resynced`.
- The UI Framework **must** report a replay-indicator click as its own event, never as `confirm`, so a click on the latched indicator can un-latch. A `false` from `request_latch()` or `clear_latch()` **must** produce the refusal feedback.
- `BattleHud` and the Battle mode **must** connect only to the controller's signals, and **must never** connect to `BattleCore.turn_started`, `round_advanced` or `battle_ended` directly.
- `BattleHud` **must** read HP, MP and status only through `get_display()`, and the round only through `get_display_round()`.
- Presentation **must** take beat-driven animation frames, the punch's `t` and the takeover's `t_blend` only from the controller's three clocks. It **must not** run its own `Tween`, `Timer` or `AnimatedSprite3D` playback for them.
- Only the Battle mode's `_process` **may** call `advance()`. No `Timer`, `Tween`, `SceneTree` or `Time` access **may** be added to the controller.
- During a replay, `confirm`, `fast_forward` and `cancel` presses **must** be consumed by the latch methods and **must never** be buffered or passed on.
- The Battle mode **must** call `cancel_pending_replay()`, and stop its end-of-fight hold, on every `transition_started` from BATTLE (to another mode, or Battle → Battle for Retry), and again first thing in `restore_start_snapshot()`. It **must** call `dispose()` from `_exit_tree()`.
- The controller's queue, snapshots and clocks are private. Its signals and public methods are its whole surface.
- **Process order.** In its `_process`, the Battle mode calls `controller.advance(delta)` **first**, then pushes the results down: `stage.set_punch_offset_px()`, each `CharacterSprite.show_frame()`, and the HUD refresh. No reader polls the controller from its own `_process`, so nothing is a frame stale and no `process_priority` is needed.
- **Re-entrancy.** Signals are emitted synchronously inside `advance()` and inside `BattleCore`'s own emission. A handler **must not** call `cancel_pending_replay()`, `dispose()`, `submit_action()` or any queue method directly; it uses `call_deferred()`. The controller enforces it: while it is emitting, those methods log an error in debug builds and are deferred to the end of the current `advance()` (or the current `BattleCore` emission). A test harness that auto-submits actions on `turn_started` must defer the submit, or the IDLE immediate-release path recurses into `BattleCore`.
- **Hard prerequisite:** none of the above can be built until ADR-0002 Migration Step 2 has moved `BattleCore` construction out of `ChapterFlow`. Stories for the Battle mode and `BattleHud` rewiring are not Ready before it.

## Alternatives Considered

### Alternative 1: Defer emission inside `BattleCore` itself
- **Description**: Add a "replay done" input to `BattleCore` and have it hold `turn_started`/`battle_ended` until told to release them.
- **Pros**: One fewer class; no new listener.
- **Cons**: Pulls animation timing into the one class the project keeps headless. Every `BattleCore` test asserting signal timing would need an extra release call. It mixes Turn Battle's job (what happened) with Presentation's (how it is shown).
- **Rejection Reason**: Breaks ADR-0002's headless-`BattleCore` constraint, and changes a shipped, tested contract to serve one consumer.

### Alternative 2: No dedicated controller — `await` chains in `BattleHud`
- **Description**: `BattleHud` keeps connecting to `action_resolved`, awaits a `Tween` or `Timer` per outcome before updating, and tracks "mid-replay" as a local flag.
- **Pros**: No new file.
- **Cons**: Moves the gap into a `Control` script instead of closing it. It can't be tested headlessly, every other consumer of `battle_ended` still sees the raw signal, and tweens would give sprites, punch and sound separate clocks.
- **Rejection Reason**: Gives the replay no single testable owner and no single clock.

### Alternative 3: Per-target delta arithmetic for displayed HP
- **Description**: Start from one snapshot and apply each outcome's `hp_delta` to `display_hp[outcome.target]`.
- **Pros**: Smaller per-outcome state.
- **Cons**: Wrong for the party heal (`target == null`, side-total `hp_delta`), blind to MP upkeep, which has no outcome, and fragile for any future multi-target move.
- **Rejection Reason**: Snapshotting every combatant at each emission is exact for every shape, at about 8 small records per entry, and the snapshots also give per-member numbers (§7).

### Alternative 4: Keep the queue here and the timing in the GDD (revision 1's split)
- **Description**: This ADR names the queue and signals. The GDD's rule 9 owns the beat's internals, the call order and the input rules.
- **Pros**: The ADR stays short; designers edit timing in one document.
- **Cons**: Two reviews found the two documents contradicting each other in at least five places (floor before speed, HP at impact, Retry order, the missing gate, the hold API), each change in one going unmirrored in the other.
- **Rejection Reason**: The creative director ruled the split unworkable (`/design-review` 2026-10-22, ruling 3). The GDD keeps the player-facing guarantees and the formula; the mechanism lives here only.

### Alternative 5: Time-stamped press guard inside the controller
- **Description**: The controller records the replay's start time, and `request_latch(press_start_time)` rejects presses that began before it or inside a quiet period.
- **Pros**: Independent of how the Input System reports presses.
- **Cons**: Duplicates a guarantee the Input System already makes: one `pressed` per physical press, at its start (Input rule 2, AC-2). It would also need the Input System's clock injected, which the controller otherwise never needs.
- **Rejection Reason**: The gate (no press accepted before the full reveal) plus Input's one-`pressed`-per-press rule already give "a press counts only if it begins after the full reveal" (ruling 2), with no clock.

## Consequences

### Positive
- `BattleCore` and `BattleOutcome` are untouched, so Turn Battle's tests and LOW risk rating stand.
- One `RefCounted` owns the queue, the displayed state, the beat clocks, the latch, the gate and the takeover hold. It is tested headlessly with a stub signal source and explicit `advance()` deltas, with no real time spent.
- One clock per beat phase, read by sprites, punch and sound alike, so they can't drift at any speed.
- The replay freezes under the Menu with no extra code.
- Every outcome shape in the shipped code has a defined pose, reaction and number, including the party heal, zero-HP specials and Defend.
- The Retry order is consistent with ADR-0002 §7, `start_battle(false)` and the enemy reset, and needs no new Game State announcement.

### Negative
- The Battle mode carries about ten call-site obligations (§5, Implementation Guidelines). A missed one brings back the bug it guards. A control-manifest Required rule must state them, and AC-45/AC-36-style integration tests cover the order.
- Dropping leftover `dt` makes a replay up to one frame per event (two per beat) longer than the formula's continuous time.
- Move-specific animations are keyed by display name until moves get IDs.
- The automatic speed-up is deferred, so very long enemy phases are shortened only by the player's latch or Battle Speed.

## Risks
- **A story wires `BattleHud` to both the raw and the gated signals.** *Mitigation*: the Implementation Guidelines forbid it, a forbidden-pattern registry entry exists, and a unit test asserts `BattleHud` has no connection to `BattleCore.turn_started`.
- **A missed call on a Retry or exit path.** *Mitigation*: every path is named in §5, and a spy-based integration test asserts the full order on first entry, Retry and each exit.
- **`windup` returns a stale length** (for example, before a `SpriteFrames` is loaded). *Mitigation*: boot validation guarantees every action animation and `impact_frame` exists before any battle. `beat_min` floors every beat, and `-1.0` takes the debug path.
- **The gate never opens** (a missed `transition_finished` handler), so the battle soft-locks on an empty screen. *Mitigation*: an integration test drives a stub Game State through both rows. In debug builds, the Battle mode logs an error if it is still `GATED` `gate_stuck_warn_s` of mode time after `mode_entered(BATTLE)` (a `PresentationConfig` debug knob, default 2.0 s, range 1.0–5.0).
- **`move_name` collides across moves**, or is localized. *Mitigation*: content validation rejects duplicate move display names per sprite set until moves have IDs.
- **Snapshot cost grows with battle size.** About 8 records per entry at the GDD's 8 actors. Revisit above about 50 combatants.

## GDD Requirements Addressed

TR IDs from `docs/architecture/tr-registry.yaml`, assigned by `/architecture-review` on 2026-10-22 (back-fill map in `architecture-review-2026-10-22.md`).

| TR-ID | GDD System | Requirement | How This ADR Addresses It |
|-------|------------|-------------|--------------------------|
| TR-presentation-009, TR-turnbattle-005 | sprite-camera-presentation.md, turn-battle-system.md | Rule 9: the next command menu opens only when the replay has finished; Victory or Defeat only after the last beat; outcomes reach presentation only through the controller | TURN and END markers are released only after every earlier entry finishes (§4 step 4) |
| TR-presentation-009 | sprite-camera-presentation.md | Rule 9: wind-up → impact → hold → number; the hold never scales; every beat lasts at least `beat_min` | §4's two-phase beat: scaled wind-up, unscaled post-impact clock, end condition `hold ∧ beat_min`; displayed state changes at `beat_finished` |
| TR-presentation-010 | sprite-camera-presentation.md | Rule 9: one clock drives sprite frames, the punch and sound | §4's three clocks and `beat_impact`; Implementation Guidelines forbid presentation's own timers. The frame-setting side is ADR-0005 §1 |
| TR-presentation-009 | sprite-camera-presentation.md | Rule 9: every outcome shape has a defined pose; no "0" numbers; per-member party-heal numbers | §7's map and snapshot-derived `hp_changes` |
| TR-presentation-011 | sprite-camera-presentation.md | Rule 9: one-level latch over every wind-up; the boss entrance only with "Speed up boss entrances"; Cancel or a second indicator click clears; a press that changes nothing is refused; the passive indicator; no buffering; a press counts only after the full reveal | §6 (`request_latch`, `clear_latch`, `is_press_effective`) |
| TR-presentation-009 | sprite-camera-presentation.md | Rule 9: a knockout holds until its slump has landed; a beat with no reactor has no hold; the actor never reacts to its own action | §7 `hold`, `reactions` |
| TR-presentation-013 | sprite-camera-presentation.md | Rule 9: turn-start changes (a Defend wearing off, a stun clearing) and the round show when released, never stale; Retry starts clean | §2 TURN/END snapshots, §8 `get_display_round()`, `display_resynced` (§3, §5) |
| TR-presentation-005 | sprite-camera-presentation.md | Rule 6: the boss takeover holds the first turn, starts on the first fully revealed frame, plays in full on first entry and settles on Retry | GATE + HOLD entries (§2, §5); `get_hold_time()` drives the blend. The flood and sky are ADR-0005 §3 |
| TR-presentation-009, TR-presentation-013 | sprite-camera-presentation.md | Rule 9 / Edge Cases: Retry, Retreat, Quit and freeing mid-replay drop everything; Menu freeze; slow frames never skip a beat | §5 exit order, §8 cancel/dispose, §4 clamp and drop-leftover rule |
| TR-presentation-021 | sprite-camera-presentation.md | Replay knobs in presentation data, validated at load | §9 (`PresentationConfig` replay fields) |
| — (no TR) | sprite-camera-presentation.md | Interactions table: is-boss and faction come from the encounter descriptor; the boss actor is the `is_boss` enemy | §5 step 2, `boss_combatant` |
| TR-turnbattle-005 | turn-battle-system.md | Synchronous resolution and the outcome log stay as built; a replay never changes a result | `BattleCore` is not modified |
| — (no TR) | game-state-scene-flow.md / ADR-0002 §7 | Retry restores the start snapshot on the same instance; Defeat Prompt after the outcome is reported | §5 Retry order; end-of-fight holds before `report_battle_outcome()` |

## Performance Implications
- **CPU**: Negligible. One queue append, one plan and one snapshot of about 8 records per emitted signal; one `advance()` per frame doing constant work.
- **Memory**: One controller per Battle-mode instance. The queue holds one replay's entries at most and empties as it drains.
- **Load Time**: None.
- **Network**: Not applicable.

## Migration Plan
0. **Prerequisite:** ADR-0002 Migration Step 2 (the Battle mode constructs and owns `BattleCore`; `ChapterFlow` stops constructing it, listening to `battle_ended` and retrying).
1. Write `BattleReplayController`, `BeatPlan` and `CombatantDisplay`, with gdUnit4 tests under `tests/unit/battle/` against a stub signal source (Validation Criteria).
2. Rewire `BattleHud` to the controller's signals and `get_display()`, and add the replay indicator.
3. In the Battle mode: §5's first-entry, Retry and exit order; `advance()` from `_process`; input routing (§6); the end-of-fight holds.
4. Register the control-manifest rules for the Battle mode's call-site obligations.
5. Re-run `/design-review design/gdd/sprite-camera-presentation.md` against this revision, then `/architecture-review`.

## Validation Criteria
Unit tests, with a stub `BattleCore` signal source and explicit `advance()` deltas:
- **Order:** for a replay with several outcomes, a ROUND and a TURN, signals come out as `replay_started`, then per outcome `beat_started` → `beat_impact` → `beat_finished`, then `replay_finished`, `round_advanced_after_replay`, `turn_started_after_replay`, in that order.
- **Clocks:** `beat_impact` fires on the first frame where `windup_progress ≥ w`; `beat_finished` on the first frame where `post_impact_time ≥ hold` and `elapsed ≥ beat_min`; leftover `dt` is not carried. At every speed, the impact-to-finish time is `hold` within one frame unless the floor extends it.
- **Slow frame:** `advance(0.5)` with `dt_max = 0.1` finishes at most one timed entry.
- **Gate:** while `GATED`, `advance()` changes nothing and `request_latch()` returns false. `open_reveal_gate()` starts the next entry on the next `advance()`.
- **Takeover:**
  - With `speed_up_boss` off, `TAKEOVER_FULL` lasts `blend_boss + boss_hold` at 1×, even with Faster battle animations on and latched.
  - With `speed_up_boss` on, it lasts `/ battle_speed_mult` with Faster battle animations on and no latch, and `/ ff_mult` latched.
  - `TAKEOVER_SETTLE` lasts `boss_retry_hold`, `/ battle_speed_mult` and `/ ff_mult` in the same cases.
  - No `beat_started` or `turn_started_after_replay` comes before `hold_finished`.
- **Latch:**
  - Latched, every wind-up, knockouts included, plays at `ff_mult`. `clear_latch()` restores them from the next frame. The latch is false at the next `replay_started`.
  - `request_latch()` returns false while latched, in `GATED`, and while `is_press_effective()` is false.
  - `clear_latch()` returns false while unlatched, and while `is_press_effective()` is false.
- **Press effectiveness:** `is_press_effective()` is false on exactly the frames where only post-impact holds remain, or only a `TAKEOVER_FULL` with `speed_up_boss` off. `press_effective_changed` fires once per change.
- **Map:** these moves are each resolved by `BattleCore`'s own resolution of the shipped moves, with a seeded RNG: an Attack hit, a 0-damage Attack, a knockout, Defend, Family Meal over 3 members including the healer, the single heal, Home Run, Stun and Viral Stunt. For each, the plan's roles, reactions, `hp_changes`, `punch`, `big_punch`, `knockout` and `hold` match §7. No plan has a 0 in `hp_changes`, and no plan lists its actor in `reactions`.
- **Holds:** a Defend plan's `hold` is 0. A knockout plan's is `max(ko_hold, ko_landing)` for a landing both before and after `ko_hold`.
- **Display:** `get_display(c)` equals live values for every combatant on every released TURN and once the queue drains. That includes after a party heal, after MegaCorp's upkeep, on the turn a squad member's Defend wears off, and after a stunned enemy's skipped turn. Before a beat finishes, it shows the previous snapshot. `get_display_round()` changes only when a ROUND is released.
- **Cancel and resync:** after `cancel_pending_replay()` mid-beat, no discarded signal is emitted and `replay_cancelled` fires once. After §5's Retry order, `get_display(c)` equals the restored party values and the full-reset enemy values, and `display_resynced` fired once.
- **Dispose:** after `dispose()`, emitting on the stub reaches nothing.

Integration (stub Game State, real `BattleCore`):
- the first-entry and Retry call orders of §5, asserted by a spy, including the cancel on `transition_started(BATTLE, BATTLE)` and the end-of-fight hold stopped by an exit;
- after a Retry, the HUD shows no number and every sprite is in `idle` on the first frame after the flash;
- the first command menu opens only after `transition_finished(BATTLE)`, and after the takeover in a boss fight.

A retained screenshot (Visual/UI evidence gate) shows the command menu closed until the last beat finishes, once the Battle mode story is built.

## Related
- Extends ADR-0002 §2, §4–§8. Enables ADR-0005 (presentation consumes this controller's clocks and signals). Supersedes neither.
- `design/gdd/sprite-camera-presentation.md` rules 6 and 9 (revision 6) state the player-facing guarantees and the `replay_time` formula this ADR implements.
- `design/gdd/input-system.md` rule 2 and AC-2 (one `pressed` per physical press) are relied on by §6.
- `design/gdd/turn-battle-system.md`: unaffected; `BattleCore`'s public contract is unchanged.

## Review History
- 2026-10-21 — godot-specialist: APPROVE with minor notes (code citations verified; beat clock and signal teardown unspecified; precedent overstated; typed `Dictionary` not sourceable). All folded in.
- 2026-10-21 — technical-director (TD-ADR): CONCERNS (party-heal displayed HP, beat clock, Retry snapshot staleness and construction order, `round_advanced` ungated, unused `is_boss`/`faction_id`, inverted layering, no TR IDs). Revised in autonomous mode: snapshots per outcome, `advance()` clock, `resync()` and construction order, ROUND marker, boss/faction removed from the controller, file moved to `src/battle/`, TR-ID gap stated.
- 2026-10-22 — **Revision 2**, per creative-director ruling (3) of the fourth `/design-review` of `sprite-camera-presentation.md` (MAJOR REVISION NEEDED). The whole controller contract moved here. Changes from revision 1:
  - **States and signals:** a state machine (§3) with the new signals `replay_started`, `replay_finished`, `replay_cancelled`, `latch_changed`, `hold_started`/`hold_finished` and `beat_impact`.
  - **Queue:** a reveal **GATE** and a takeover **HOLD** entry (`enqueue_reveal_gate`, `open_reveal_gate`, `enqueue_takeover`).
  - **Clock:** the beat is a scaled wind-up plus an unscaled post-impact clock, ending on `hold ∧ beat_min`. This replaces revision 1's "floor before speed" duration, and leftover `dt` is dropped (§4).
  - **Display:** HP now changes at `beat_finished`, not "at impact". Snapshots also carry MP and status, plus a ROUND snapshot for upkeep (§2, §8).
  - **Map:** an outcome-to-animation map with per-combatant reactions and numbers from the snapshots (§7). `defend` becomes a required animation.
  - **Input:** `set_speed_inputs(fast_forward_held, …)` is replaced by a one-level latch (`request_latch`, `clear_latch`) and `set_speed_settings(battle_speed_2x, speed_up_all)` (§6).
  - **Call order:** the Retry order is corrected against ADR-0002 §7: inside `restore_start_snapshot`, `start_battle(false)` comes before `resync()`. The gate opens on the Battle → Battle row's `transition_finished` (§5).
  - **Lifetime:** cancel on `transition_started` away from BATTLE; `BattleCore` lives as long as the Battle mode; `boss_combatant` is resolved from `Combatant.is_boss`.
  - **Removed:** `replay_cap` and the automatic speed-up (deferred), and `speed_max`, which was unreachable without them.
  - **Hard prerequisite:** ADR-0002 Migration Step 2.
  - **Pending:** a fresh godot-specialist and TD-ADR review of this revision.
- 2026-10-22 — **Revision 3**, per the fifth `/design-review` of `sprite-camera-presentation.md` (NEEDS REVISION) and its tracked list. Changes from revision 2:
  - **Snapshots** at the TURN and END markers, applied on release. This fixes the Defend and stun flags that went stale at turn start (AC-14 failed), and adds `get_display_round()`.
  - **Signals:** `display_resynced()`, emitted by `resync()`, so the HUD and sprites reset on Retry, and `press_effective_changed()`.
  - **Call order:**
    - first entry clears the squad's transients and ends with `resync()`;
    - Retry also cancels on `transition_started(BATTLE, BATTLE)`;
    - every exit and Retry stop the end-of-fight hold;
    - a capped retry flash turns the light swap into a `blend_defeat` blend.
  - **Speed** (rulings 1–3):
    - knockouts are plain beats, and `protected` is false in MVP;
    - `TAKEOVER_FULL` takes the plain-beat speed with `speed_up_boss` (renamed from `speed_up_all`);
    - `request_latch()` and `clear_latch()` return false for a press that changes nothing;
    - `is_press_effective()` was added;
    - an indicator click toggles the latch;
    - `battle_speed_mult ≤ ff_mult − 0.25`.
  - **Map:** the actor is never in `reactions`; a knockout's `hold` comes from the injected `ko_landing`; a plan with no reactors has `hold = 0`.
  - **Timing tolerance** is per event, not per beat.
  - **Pending:** a fresh godot-specialist and TD-ADR review of revisions 2 and 3 together.
- 2026-10-22 — **Review of revision 3** (godot-specialist; technical-director TD-ADR). godot-specialist: APPROVED. TD-ADR: ACCEPT WITH CONDITIONS. All eight review-5 tracked items confirmed landed; `replay_time` matches the GDD line for line.
  - **[BLOCKING — condition] §5 step 3 (L229):** name who requests `boss_<faction>` on `hold_started(TAKEOVER_FULL)` with the hold clock (align with the ADR-0005 fix), and how the Battle mode learns that the Retry flash played capped (e.g. a `GameStateMachine` query, or the `FlashGate` result passed with the transition).
  - Recommended: process order (the Battle mode calls its readers after `advance()`, or pins `process_priority`); a re-entrancy rule for handlers that call `cancel_pending_replay()`, `dispose()` or `submit_action()` during emission; `dispose()` also drops `ko_landing` and `config`; typed `Dictionary[Combatant, int]` (compiles on 4.7.2); default `_init` arguments for gdUnit4 spies; the 2 s still-GATED debug literal becomes a data knob; this revision gets its own Review History line (the "Pending" note above is now resolved).
  - Acceptance: together with ADR-0005, after ADR-0004 → ADR-0002 and after `/architecture-review` assigns TR IDs.
- 2026-10-22 — **Revision 4**, answering the review of revision 3:
  - **The condition:** §5 now names the Battle mode as the only caller of `request_profile()`. On first entry it requests `boss_<faction>` on `hold_started(TAKEOVER_FULL)` with a hold-clock `Callable` (step 11). On Retry, step 3 asks `GameStateMachine.is_transition_flash_capped()` (ADR-0002 amendment) and requests blend 0 or `blend_defeat`. The Director's same-mode `mode_entered` doesn't overwrite it (ADR-0005 §4).
  - **Recommended items applied:**
    - `dispose()` drops `ko_landing` and `config`;
    - `gate_stuck_warn_s` is a debug knob;
    - typed `Dictionary[Combatant, …]`;
    - default `_init` arguments for gdUnit4 spies;
    - process order: `advance()` first, then push down;
    - the re-entrancy rule.
  - **Pending:** a short re-review, together with ADR-0005 revision 3.
- 2026-10-22 — **Short re-review of revision 4** (TD-ADR): **ACCEPT**. The condition is CLOSED and all six recommended items landed. Follow-up in ADR-0005 §12: the Battle mode calls `FlashGate.cancel()` on its replay-clock bookings next to each `cancel_pending_replay()`.
- 2026-10-22 — **`/architecture-review` fixes** (`architecture-review-2026-10-22.md`), no decision change:
  - **Dependency cycle cut:** ADR-0005 moved from Depends On to Enables. In code the edge only ran one way (Core takes the clocks as `Callable`s and never imports this Feature controller).
  - **TR IDs back-filled** into GDD Requirements Addressed: TR-presentation-005, 009, 010, 011, 013, 021; TR-turnbattle-005.
  - **Engine Compatibility:** the Verification Required row now matches §7 (typed `Dictionary[Combatant, …]`, probed on 4.7.2).
  - Advisory E6 (the boss-light `clock` lambda outlives `dispose()`; the stage should drop it when the blend completes and on `_exit_tree`) is not yet folded in.
- 2026-10-22 — **Accepted** by the user, after ADR-0002 → ADR-0004 → ADR-0003 (explicit instruction to accept in that order, then ADR-0006, then ADR-0005). No stories were Blocked on this ADR.
