# Game State & Scene Flow

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-10-23 (rules 2, 4 and 9 synced to ADR-0002 §11 and Overworld GDD OQ-18)
> **Last Verified**: 2026-10-13
> **Implements Pillar**: Readable in One Turn (supports the 30-second and 5-minute loops)

## Summary

Game State & Scene Flow decides which mode the game is in (boot, title, overworld, battle, camp) and which overlays (menu, dialogue, defeat prompt) sit on top, and it performs every transition between them. For the player, this is the snappy Dragon Quest-style wipe into a separate battle, the return to exactly where they stood, an instant Retry or a Retreat to the last camp after a loss, and a pause that truly stops time. It exists so every flow change in the game goes through one predictable, testable place.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Content Data Definitions, Input System`

## Overview

Game State & Scene Flow is the traffic controller for the whole game. It decides which mode the game is in (boot, title, overworld, battle, camp, and the overlays that sit on top of them, such as dialogue and menus), and it owns every transition between them. Other systems never switch scenes themselves: they *request* a transition, and this system performs it, freezes and restores whatever must survive it, and tells everyone what changed.

The player never sees it as a feature, but feels it constantly. Every step of the core loop passes through it: walking the overworld, a wipe into a separate Dragon Quest-style battle scene, the victory fanfare, and back to exactly where they stood. A loss offers an instant retry. If any of that is slow, inconsistent or loses state, the loop breaks, so the system's job is to make every transition fast, predictable and lossless (Readable in One Turn applies to the game's flow as much as to its fights). How scenes are implemented in Godot (autoloads, scene swapping, sub-viewports) is an ADR decision, not part of this GDD.

## Detailed Design

### Core Rules

**1. Modes and overlays.** At any moment the game is in exactly one **mode**: Boot, Content Error, Title, Overworld, Battle or Camp. On top of the current mode, zero or more **overlays** may be open, stacked: Dialogue, Menu (pause, party, Codex, settings) and Defeat Prompt. Only the top overlay receives input. With no overlay open, the mode receives input.

**2. One door in.** No other system switches modes or opens overlays directly. They call `request_transition(target_mode, payload)` or `open_overlay(kind, payload)` / `close_overlay()`. This system is the only place a mode changes, so every change can be logged, tested and restored. *(2026-10-23, Overworld GDD OQ-18 and ADR-0002 §11, pending ADR-0012 acceptance:)* a fourth door, the **in-mode fade**, lets the Overworld fade out and back in without changing mode, for a checkpoint redirect. It is legal only in the Overworld with no overlay open, locks input and blocks saving like any transition, and announces only `transition_started` and `transition_finished`.

**3. One transition at a time.** A transition runs in three phases: **out** (wipe or fade), **swap** (the old mode is frozen or released, the new one prepared), and **in** (reveal). Player input is locked from the start of *out* to the end of *in*. A transition request made while another is running is **rejected** with an error, not queued. The one exception is Quit (rule 12).

**4. Announcements.** Every change broadcasts, in order: `transition_started(from, to)`, `mode_exited(from)`, `mode_entered(to)`, `transition_finished(to)`. Overlays broadcast `overlay_opened(kind)` and `overlay_closed(kind)`. Audio, Presentation and UI react to these announcements; they never poll. The one exception is the in-mode fade (rule 2), which announces only `transition_started(from, from)` and `transition_finished(from)`, because no mode is exited or entered.

**5. Overworld survives battles.** Entering Battle from the Overworld **freezes** the overworld rather than discarding it: party position and facing, current map, NPC and enemy states, and story flags. After a Victory or a successful Flee, the overworld is restored exactly as it was. The encounter that started the fight is then resolved according to Overworld's rules (e.g. that enemy is removed).

**6. Battle entry.** Every battle starts from an **Encounter descriptor** passed as the payload: `encounter_id`, the enemy group (Enemy IDs), `battle_stage_id` (which battle diorama), `faction_id` (rule set and lighting), `is_boss`, `can_flee`, and `retreat_allowed` (false only for scripted story fights such as the tutorial). The descriptor's fields are owned by Overworld and Turn Battle (*provisional* until those GDDs exist). This system only carries it and snapshots it.

**7. Battle exit.** Turn Battle ends every fight by reporting an outcome: **Victory**, **Fled** or **Defeat**. Victory: after Battle's own results screen, transition to Overworld (rule 5 restore). Fled: transition to Overworld (rule 5 restore). Defeat: open the Defeat Prompt overlay (rule 8).

**8. Defeat Prompt: Retry or Retreat.**
- **Retry** restarts the same battle from its exact starting snapshot, taken when the battle began: party stats, items and states, enemy group, and turn order inputs. Retry needs no new scene load, so it is the fastest transition in the game. Whether randomness repeats on retry is Turn Battle's decision.
- **Retreat** (shown only when `retreat_allowed`) transitions to Camp at the **last camp the squad visited**, with the party fully restored. The frozen overworld snapshot from that battle is discarded. When the squad later leaves camp, they appear at that camp's overworld location. In MVP, retreat carries no penalty (see Open Questions).

**9. Camp.** Entered from the Overworld at a camp spot (Overworld owns where those are) or by Retreat. Leaving camp always returns to the overworld at that camp's location. Entering camp records it as the **last camp registered**. *(2026-10-23, Overworld GDD OQ-18:)* the Overworld may also register a camp the squad merely walks past (its safe zone), through this system, which stays the only writer; Retreat goes to the last camp registered.

**10. Menu overlay.** The player can open the Menu in Overworld, Camp and Battle (in Battle, only the system menu: settings and quit), but never during a transition, in Boot, or in Content Error. While the Menu is open, the underlying mode's time stops (animations, timers, ambient motion). Per the art bible, menus show the frozen, blurred diorama behind flat UI.

**11. Dialogue overlay.** Dialogue opens as an overlay in Overworld and Camp and blocks the mode beneath it. In Battle, banter is non-blocking and is not an overlay (it belongs to Turn Battle and Dialogue). Dialogue may end by requesting a transition (e.g. a story fight). The overlay closes first, then the transition runs.

**12. Title and Quit.** Title offers New Game, Continue (disabled until Save/Load exists in the Vertical Slice), Settings and Quit. Quit is available from Title and the Menu, always asks for confirmation, and is the only request accepted during a transition (it waits for the current transition to finish, then exits).

**13. Boot.** Boot starts the Content Data load and waits. Ready leads to Title. Failed leads to Content Error, a terminal mode showing the plain error screen defined in Content Data Definitions, where the only action is Quit.

### States and Transitions

**Modes**

| From | To | Trigger | Transition |
|---|---|---|---|
| (start) | Boot | Game launched | none |
| Boot | Title | Content catalog Ready | fade |
| Boot | Content Error | Content catalog Failed | none (instant) |
| Title | Overworld | New Game / Continue | fade |
| Overworld | Battle | Encounter starts (rule 6) | battle wipe |
| Battle | Overworld | Victory (after results) or Fled | battle wipe, reversed |
| Battle | Battle | Retry from Defeat Prompt | quick flash; no scene load |
| Battle | Camp | Retreat from Defeat Prompt | fade |
| Overworld | Camp | Squad enters a camp spot | fade |
| Camp | Overworld | Leave camp | fade |
| Overworld | Overworld | Move to another map or region | fade (new map loads) |
| any except Content Error | Title | Quit to title (Menu) | fade |
| Title / Menu | (exit) | Quit confirmed | none |

Any pair not in this table is invalid and is rejected with an error.

**Overlays**

| Overlay | Can open over | Opened by | Closes to |
|---|---|---|---|
| Menu | Overworld, Camp, Battle (system menu only) | Player input | Mode beneath, resumed |
| Dialogue | Overworld, Camp | Dialogue system | Mode beneath, or a transition (rule 11) |
| Defeat Prompt | Battle | Battle outcome Defeat | Retry (Battle) or Retreat (Camp) |

### Interactions with Other Systems

| System | Gives this system | Gets from this system |
|---|---|---|
| Content Data Definitions | Catalog status (Ready / Failed) | Boot starts the load |
| Input System | Player input | Which mode or overlay currently owns input; input lock during transitions |
| Overworld Exploration & Encounters | Encounter descriptors; camp spots; map change requests | Freeze/restore of overworld state; `mode_entered` announcements |
| Turn Battle System | Battle outcome (Victory / Fled / Defeat) | Encounter descriptor; Retry with the starting snapshot |
| Camp & Party Management | Leave-camp request | Camp entry; "last camp visited" |
| Dialogue, Banter & Quests | Open/close Dialogue overlay; follow-up transition requests | Overlay ownership of input |
| Sprite & Camera Presentation | — | Announcements, used to apply each mode's lighting signature and camera |
| Audio Manager | — | Announcements, used to switch music and ambience |
| UI Framework | Renders transitions, Menu, Defeat Prompt and Title | Overlay open/close; transition phase timing |
| Save/Load & Settings (Vertical Slice) | Continue data | Safe save moments (mode is Overworld or Camp, no overlay except Menu, no transition running) |

## Formulas

> `systems-designer` not consulted (lean mode). The values below are starting targets to tune on the development PC, not balanced numbers.

The transition_time formula is defined as:

`transition_time = t_out + t_swap + t_in`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| t_out | float (s) | 0.15–0.50 | data file (per transition type) | Wipe/fade-out duration |
| t_swap | float (s) | 0.00–0.60 | calculated (measured) | Time to freeze or release the old mode and prepare the new one (scene loading) |
| t_in | float (s) | 0.15–0.50 | data file (per transition type) | Wipe/fade-in duration |
| transition_budget | float (s) | per type, see below | data file | Maximum allowed `transition_time` |

**Budgets (starting targets):**

| Transition | t_out | t_in | transition_budget |
|---|---|---|---|
| Overworld → Battle (wipe) | 0.35 | 0.30 | 1.0 s |
| Battle → Overworld (wipe, reversed) | 0.30 | 0.30 | 1.0 s |
| Retry (flash) | 0.10 | 0.15 | 0.5 s |
| Fades (camp, map change, title, retreat) | 0.25 | 0.25 | 1.5 s |

**Output Range:** 0.25 s (Retry with no load) to 1.5 s (a fade with a new map load). If `t_swap` would exceed the budget, the *in* phase still waits for the swap to finish. The overrun is logged as a performance warning, never skipped, so the player never sees a half-built scene.

**Example:** Overworld → Battle with a 0.20 s stage load: `0.35 + 0.20 + 0.30 = 0.85 s`, within the 1.0 s budget.

## Edge Cases

**Requests and timing**
- **If a transition is requested while another is running**: the request is rejected with an error returned to the requester, and the state is unchanged. Exception: Quit waits for the running transition to finish, then exits.
- **If a requested from → to pair is not in the transitions table**: rejected with an error and logged; the state is unchanged.
- **If any request arrives while in Content Error**: rejected. Content Error is terminal, and only Quit works.
- **If `t_swap` exceeds the transition budget**: the *in* phase waits for the swap to complete and a performance warning is logged. The player never sees a partly built scene.
- **If the player presses Retry repeatedly**: input is locked during the Retry transition, so extra presses are ignored and exactly one battle restart happens.
- **If two requests arrive in the same frame**: the first one received is accepted and the others are rejected as "transition running". Order of receipt is deterministic (the order the requests were made).
- **If an overlay open or close is requested during a transition**: rejected. The Defeat Prompt is never affected, because Battle only reports Defeat outside transitions.
- **If the swap phase fails** (the new scene fails to load): the transition rolls back to the previous mode, restoring any frozen state, the reveal plays back into it, input unlocks, and an error is logged. The game is never left between modes or with input locked.

**Overlays**
- **If a system requests a transition while the Menu is open**: rejected. The mode's time is stopped while the Menu is open, so encounters and timers cannot fire. Quit to Title from the Menu itself is the only transition allowed.
- **If the Dialogue system tries to open Dialogue while the Menu is open**: rejected. The Dialogue system retries after `overlay_closed(Menu)`. The reverse is allowed: the Menu can open over Dialogue (pause mid-conversation), and closing it returns to that Dialogue.
- **If the game window loses focus, or Input reports a controller disconnect**: the Menu opens automatically wherever it is allowed (rule 10). During a transition, the Menu is deferred: it opens right after `transition_finished`, if focus is still lost. In Boot and Content Error, the notice is ignored.

**Battle flow**
- **If the Encounter descriptor is invalid at runtime** (unknown enemy ID, missing battle stage): the battle does not start, the player stays in the Overworld, and an error is logged. Content Data validation should catch this at boot, so a runtime occurrence is a bug.
- **If `retreat_allowed` is false**: the Defeat Prompt shows only Retry.
- **If the player Retreats before visiting any camp**: they go to the region's **default camp**, which every region must define (an Overworld data requirement).
- **If no camp has been visited and the region has no default camp**: Retreat is hidden (the Prompt offers only Retry) and an error is logged, because this is a content bug.
- **If Battle reports Fled when the descriptor's `can_flee` was false**: the outcome is rejected, an error is logged, and the battle continues. This is a Turn Battle bug.
- **If a battle sets story flags** (e.g. a boss defeated): the overworld is restored first, then Overworld applies the consequences after `mode_entered(Overworld)`, so the restore itself is always exact.
- **If a victory triggers story dialogue**: the Battle → Overworld transition finishes first, then Dialogue opens as an overlay. A story dialogue never opens over a half-revealed scene.
- **If the player quits during a battle or with unsaved progress**: the confirmation message says progress since the last save will be lost. Before Save/Load exists, it says all progress will be lost.

## Dependencies

**Upstream (this system depends on):**

| System | Nature | Interface |
|---|---|---|
| Content Data Definitions | Hard | Boot waits for catalog Ready; Failed leads to Content Error (Content Data rule 8 and the error screen) |
| Input System | Hard (*provisional*: Input GDD not yet written) | Input is a pure device → action layer with no knowledge of modes. This system routes actions (`confirm`, `cancel`, `menu`, directions) to the current mode or top overlay, and receives `device_lost` / focus-lost notices |

**Downstream (these systems depend on this one):**

| System | Nature | What it relies on |
|---|---|---|
| Overworld Exploration & Encounters | Hard | Freeze/restore around battles, map-change transitions, encounter → battle requests |
| Turn Battle System | Hard | Encounter descriptor in, outcome out, Retry snapshot |
| Camp & Party Management | Hard | Camp entry and exit, "last camp visited" |
| Dialogue, Banter & Quests | Hard | Dialogue overlay and follow-up transitions |
| Sprite & Camera Presentation | Hard | Mode announcements to apply lighting and camera |
| UI Framework | Hard | Overlay lifecycle, transition phases, Title, Menu, Defeat Prompt |
| Audio Manager | Soft | Mode announcements for music changes; works without them, just silently |
| Save/Load & Settings | Soft (Vertical Slice) | Safe save moments; Continue on Title |

**Bidirectional notes:** Content Data Definitions already lists this system as a hard dependent. The systems index row for this system is updated to depend on Content Data Definitions and Input System, and Input's own GDD must state that it does **not** depend on this system (so there is no cycle).

## Visual/Audio Requirements

> `art-director` not consulted (lean mode); all look decisions defer to the art bible.

- **Battle wipe** (Overworld ↔ Battle): the signature transition of the game, played hundreds of times. It must read as "a fight starts" instantly. Its style (e.g. a diorama-card flip or a stamp slam tinted by the encounter's faction shape) is an art-direction decision for `/asset-spec`. It must not use faction color unless the encounter belongs to that faction (art bible Principle 3).
- **Fades** (camp, maps, title, retreat): neutral Ink Navy (#1B2440) fades, never a faction color.
- **Retry flash**: a short cream (#F4EAD2) flash. It should feel like "rewind", not like a new fight. It counts toward the global photosensitivity limit (`flash_gate`, at most 3 full flashes per second, `design/gdd/sprite-camera-presentation.md`). If it would land inside that gap, for example right after a victory burst, it plays as a soft fade below the flash threshold; its timing never changes.
- **Per-mode look**: on `mode_entered`, Presentation applies that mode's lighting signature from art bible §2 (golden-hour overworld, neutral battle key light, campfire camp, frozen blurred diorama behind menus).
- **Audio**: each mode change cues Audio Manager. Battle music starts during the wipe's *out* phase, so the fight begins on the beat. The Defeat Prompt uses a short, wry sting, never a dirge.

## Game Feel

- Transitions are **snappy, never sluggish**. The budgets in Formulas are upper limits, not targets to fill.
- Retry must feel near-instant. This is the "try again, you learned something" promise from the concept and the art bible's defeat mood.
- Input locks for exactly the duration of a transition. The first input after *in* completes is accepted, so there is no dead time after the reveal.

## UI Requirements

This system owns the *lifecycle* of four screens. Their layout and visuals belong to the UI Framework.
- **Title**: New Game, Continue (disabled until Save/Load exists), Settings, Quit.
- **Menu overlay**: pause/party/Codex/settings hub. In Battle, only the system menu (settings, quit).
- **Defeat Prompt**: Retry, plus Retreat when allowed, over the defeat card described in art bible §2 ("CLAIM DENIED"-style, neutral navy).
- **Quit confirmation**: states what progress will be lost.

All four must be fully navigable by keyboard and gamepad.

> **📌 UX Flag — Game State & Scene Flow**: This system has UI requirements (Title, Menu hub, Defeat Prompt, Quit confirmation). In Pre-Production, run `/ux-design` for these screens before writing epics. Stories should cite `design/ux/[screen].md`, not this GDD.

## Cross-References

| This GDD references | Document | What is referenced |
|---|---|---|
| Boot waits for catalog Ready; Content Error screen | `design/gdd/content-data-definitions.md` | Rule 8 (validation), States table, UI Requirements (error screen) |
| Instant retry; DQ-style battles; core loop | `design/gdd/game-concept.md` | Flow State Design ("Recovery from failure"), Core Loop |
| Per-mode lighting; defeat card; menu backdrop; faction color rules | `design/art/art-bible.md` §1–§2, §4 | Mood table, Principle 3, UI vs world palette |
| Fixed battle camera | `design/art/art-bible.md` §1 production notes | Decided 2026-10-13 |
| Layer and design order | `design/gdd/systems-index.md` | Foundation, MVP; depends on Content Data Definitions and Input System |

## Acceptance Criteria

Tests drive the system through its request API with stubbed neighbors: a stub Content catalog, a stub Battle reporting outcomes, an injectable clock, a scene-loader spy, and a synthetic input source. "Rejected" means the call returns an error result and a state probe shows mode, overlay stack and frozen snapshots unchanged. Thresholds are read from the data-driven config, never written as literals in tests.

Evidence: **[L]** Logic (gdUnit4, `tests/unit/game_state/`), **[I]** Integration (`tests/integration/game_state/`), **[UI]** retained screenshot in `production/qa/evidence/`, **[P]** performance benchmark (`tests/performance/`).

**Boot and terminal states**
- **AC-1 [L]** GIVEN a stub catalog that becomes Ready, WHEN Boot runs, THEN the mode becomes Title. GIVEN a stub that becomes Failed, THEN the mode becomes Content Error.
- **AC-2 [L]** GIVEN Content Error, WHEN each kind of request (every transition, every overlay, focus-lost) is made repeatedly, THEN every request is rejected except Quit, and the focus-lost notice is ignored.

**Transition table**
- **AC-3 [L]** Parametrized over every row of the Modes transitions table: from the source mode, the request succeeds and the mode becomes the target.
- **AC-4 [L]** Parametrized over every from → to pair *not* in the table: the request is rejected.
- **AC-5 [L]** GIVEN Overworld → Battle, THEN exactly these signals fire, once each, in this order: `transition_started`, `mode_exited`, `mode_entered`, `transition_finished` (overlay signals are not counted).

**Concurrency and input lock**
- **AC-6 [L]** GIVEN a running transition, WHEN another transition or any overlay open/close is requested, THEN it is rejected.
- **AC-7 [L]** GIVEN two transition requests in the same frame, THEN the first is accepted and the second rejected.
- **AC-8 [L]** GIVEN synthetic input injected during each of *out*, *swap* and *in*, THEN the mode and every overlay receive zero actions. The first action after `transition_finished` is delivered.
- **AC-9 [L]** GIVEN a running transition, WHEN Quit is requested, THEN a stubbed quit hook is called exactly once, after `transition_finished`.
- **AC-10 [L]** GIVEN a swap that fails (stub loader returns an error), THEN the mode returns to the source mode with its frozen state restored, input is unlocked, and an error is logged.

**Overworld freeze and restore**
- **AC-11 [L]** GIVEN an Overworld snapshot fixture, WHEN Overworld → Battle → Overworld runs with outcome Victory, THEN every field of the restored snapshot equals the fixture. Same for Fled.
- **AC-12 [L]** GIVEN outcome Victory, THEN the transition to Overworld starts only after Battle signals that its results screen is done.
- **AC-13 [L]** GIVEN outcome Fled on a descriptor with `can_flee = false`, THEN the outcome is rejected, an error is logged, and the mode stays Battle.
- **AC-14 [L]** GIVEN an invalid Encounter descriptor (unknown enemy ID), WHEN the battle is requested, THEN the mode stays Overworld and an error is logged.

**Defeat, Retry and Retreat**
- **AC-15 [L]** GIVEN outcome Defeat, THEN the Defeat Prompt opens. WHEN Retry is chosen, THEN the battle state equals the battle's starting snapshot fixture (party stats, items, states, enemy group), and the scene-loader spy records zero loads.
- **AC-16 [L]** GIVEN `retreat_allowed = false`, THEN the Prompt offers only Retry. GIVEN `true` followed by a Retry, THEN a later Defeat in the same battle still offers Retreat (no stale flag).
- **AC-17 [L]** GIVEN a visited camp, WHEN Retreat is chosen, THEN the mode is Camp at that camp, the party is fully restored, and the frozen overworld snapshot is discarded. GIVEN no camp visited, THEN the region's default camp is used. GIVEN no visited camp and no default camp, THEN Retreat is not offered and an error is logged.
- **AC-18 [L]** GIVEN repeated Retry inputs during the Retry transition, THEN exactly one restart occurs.

**Overlays**
- **AC-19 [L]** GIVEN overlays stacked Dialogue then Menu, THEN only the Menu receives input. Closing the Menu returns input to Dialogue, and the open/close signals fire in stack order.
- **AC-20 [L]** GIVEN the Menu open over Overworld, WHEN the injected clock advances, THEN a mode timer does not advance, a transition request is rejected, and Quit to Title from the Menu succeeds.
- **AC-21 [L]** GIVEN the Menu open, WHEN Dialogue requests to open, THEN it is rejected. GIVEN Dialogue open, WHEN the Menu opens, THEN it succeeds.
- **AC-22 [L]** GIVEN a running transition, Boot or Content Error, WHEN the Menu is requested by input, THEN it is rejected.
- **AC-23 [L]** GIVEN focus lost in Overworld, THEN the Menu opens. GIVEN focus lost during a transition, THEN the Menu opens after `transition_finished` and not before. GIVEN focus lost in Boot, THEN nothing happens. GIVEN Input's `device_lost` in Overworld, THEN the Menu opens; GIVEN `device_lost` during a transition, THEN the Menu opens after `transition_finished`.

**Cross-system**
- **AC-24 [I]** (with Dialogue) GIVEN a Victory that triggers story dialogue, THEN the Dialogue overlay opens only after `transition_finished(Overworld)`.

**Screens and performance**
- **AC-25 [UI]** Retained screenshots: Title; Defeat Prompt with and without Retreat; Menu over the live Overworld scene; Battle system menu; Camp; Content Error screen.
- **AC-26 [P]** On the reference machine (see Open Questions), the median of N runs for each transition type is within its configured `transition_budget`. A second test injects a slow swap and asserts that the *in* phase waits and a performance warning is logged.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Retreat penalty**: none in MVP. Should retreating cost something (currency, a reputation dent, a lost buff)? | user + economy-designer | Items & Shops GDD (Vertical Slice) |
| 2 | **Does randomness repeat on Retry?** Repeating it makes the retry a pure "learn the rule" replay; re-rolling it varies the fight. | Turn Battle GDD | Turn Battle design |
| 3 | **Battle wipe style** (stamp slam, card flip, etc.) | art-director via `/asset-spec` | Before the Vertical Slice art pass |
| 4 | **Scene architecture**: autoload state machine, scene swapping, how the overworld is frozen (kept in the tree vs. serialized). | `/architecture-decision` (godot-specialist) | Technical Setup |
| 5 | **Transition budgets** are starting targets set without `systems-designer`; validate them on the main PC. | user + performance-analyst | First playable build |
