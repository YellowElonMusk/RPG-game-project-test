# Go back to your planet! — Master Architecture

## Document Status
- Version: 2 (revised after TD-ARCHITECTURE and LP-FEASIBILITY CONCERNS)
- Last Updated: 2026-10-21
- Engine: Godot 4.7.2
- GDDs Covered: content-data-definitions.md, game-state-scene-flow.md, input-system.md, stats-damage-resolution.md, turn-battle-system.md, faction-rule-modifiers.md
- ADRs Referenced: ADR-0001 (Accepted)
- TD-ARCHITECTURE: 2026-10-21 — CONCERNS, REVISED after CONCERNS (see ADR Audit for the resolved items)
- LP-FEASIBILITY: 2026-10-21 — CONCERNS, REVISED after CONCERNS (see ADR Audit and Module Ownership for the resolved items)

## Engine Knowledge Gap Summary
Engine: Godot 4.7.2 | LLM Training Covers: up to ~4.3 | Post-Cutoff: 4.4, 4.5, 4.6, 4.7

- **HIGH RISK**: Input (device-ID constants, dual-focus 4.6 — not yet empirically verified in this project), UI (Control/accessibility changes, dual-focus — see Open Questions), Rendering (`AreaLight3D`, HDR, Compositor-based post-processing — relevant to the art bible's lit-diorama direction, not yet implemented or verified), Physics/Jolt (conditional — see Overworld's Open Question below; not relevant unless free-roam movement is chosen).
- **MEDIUM RISK**: Animation (Tween/IK changes), Audio (one default flipped: `area_mask`).
- **LOW RISK**: Core scripting fundamentals (`RefCounted`, `Resource`, signals, `RandomNumberGenerator`) — already exercised and empirically verified throughout the shipped battle code and ADR-0001's own verification.

This project is already deep in post-cutoff territory. The working policy going
forward: every API a story's implementation actually depends on gets empirically
verified against this exact engine build (via a throwaway headless script,
deleted after) before being trusted, rather than assumed from training data —
this is how ADR-0001's `ResourceLoader.list_directory()` claim and every battle
story's engine-specialist review were handled, and it should continue.

## System Layer Map

```
┌─────────────────────────────────────────────────────────────────┐
│ PRESENTATION  │ UI Framework (partial — battle HUD built),
│               │ Audio Manager (not built), Onboarding & Tutorial (not built)
├─────────────────────────────────────────────────────────────────┤
│ FEATURE       │ Turn Battle System (built), SquadSpecials (built — the
│               │ squad's 4 specials, see Module Ownership), ChapterFlow (built
│               │ — fight sequencing, see Module Ownership; overlap with Game
│               │ State & Scene Flow is an Open Question), Faction Rule
│               │ Modifiers (built, 2/4 factions), Quirk State System (not
│               │ built), Combo System & Codex (not built), Enemy AI (collapses
│               │ into Faction Rule Modifiers at MVP scope), Overworld
│               │ Exploration & Encounters (not built — blocked on 3
│               │ prerequisite ADRs, see Required ADRs), Camp & Party
│               │ Management (not built), Leveling & Loyalty (not built,
│               │ Vertical Slice), Faction Reputation & Endings (not built,
│               │ MVP-lite→Alpha), Items/Equipment & Shops (not built,
│               │ Vertical Slice)
├─────────────────────────────────────────────────────────────────┤
│ CORE          │ Sprite & Camera Presentation (not built — blocks Overworld),
│               │ Stats & Damage Resolution (built), Squad Roster & Recruitment
│               │ (not built), Dialogue/Banter & Quests (not built), Save/Load
│               │ & Settings (not built, Vertical Slice)
├─────────────────────────────────────────────────────────────────┤
│ FOUNDATION    │ Game State & Scene Flow (designed, not built — blocks
│               │ Overworld), Input System (designed, not built — blocks
│               │ Overworld), Content Data Definitions (designed, ADR-0001
│               │ Accepted, implementation next)
├─────────────────────────────────────────────────────────────────┤
│ PLATFORM      │ Godot 4.7.2 engine/OS — no project code, no epic
└─────────────────────────────────────────────────────────────────┘
```

Layer order reused from `design/gdd/systems-index.md`'s own dependency map.
**Build-order note** (resolves TD item 2 / LP item 1): Overworld Exploration &
Encounters is "the system requested next" only in the sense of *design*
priority — it cannot actually be *built* until Game State & Scene Flow, Input
System, and Sprite & Camera Presentation are all Accepted and implemented,
since its own Module Ownership row consumes all three. See Required ADRs for
the explicit ordering.

## Module Ownership

| System | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| Content Data Definitions | Record catalog, ID/alias resolution, Ready/Failed state | `get_record`/`has_record`/`all_records`/`resolve_alias` | — (Foundation) | `Resource`, `ResourceLoader.load()`, `ResourceLoader.list_directory()` — 4.4+, post-cutoff, **empirically verified working in 4.7.2** (ADR-0001) |
| Game State & Scene Flow | Current mode, overlay stack, transition lifecycle, frozen overworld snapshot | `request_transition(target_mode, payload)`, `open_overlay(kind, payload)`/`close_overlay()`; signals `transition_started(from, to)`, `mode_exited(from)`, `mode_entered(to)`, `transition_finished(to)`, `overlay_opened(kind)`, `overlay_closed(kind)` (named in `game-state-scene-flow.md` Rule 4) | Content Data (Ready/Failed), Input (routed actions) | Not yet implemented — scene-swap mechanism is an open ADR. **Overlap to resolve in that ADR**: `ChapterFlow` (below) already owns a slice of what this system is designed to own (battle entry/retry/results sequencing) — decide whether Game State replaces it, wraps it, or becomes its parent |
| Input System | Device state, active-device tracking, bindings | Proposed surface (not yet an ADR — named here so the ADR has a starting contract, not an invented one): `is_pressed(action)`/`is_just_pressed(action)`/`is_just_released(action)`, `get_move_vector() -> Vector2`; signals `action_pressed(action)`, `action_released(action)`, `action_held(action)`, `device_lost()`, `device_restored()`, `focus_lost()`, `focus_gained()`, `active_device_changed(kind)` (action/signal vocabulary from `input-system.md` Rules 1, 9; exact names are this system's own ADR to confirm or change) | Content Data (bindings record, soft) | `Input` singleton, `InputEvent.DEVICE_ID_MOUSE/KEYBOARD` — 4.7, post-cutoff, HIGH risk, not yet empirically verified in this project |
| Sprite & Camera Presentation | Per-mode lighting, sprite rendering, fixed battle camera | `apply_mode_lighting(mode)` | Game State (mode_entered), Content Data (asset IDs) | `Sprite3D`/`AnimatedSprite3D`, `AreaLight3D` — 4.7, HIGH risk, NEEDS VERIFICATION; `Compositor` (4.3+, training data) |
| Stats & Damage Resolution | Nothing stateful — pure functions | `DamageCalculator.calculate_damage()` only (corrected — `calculate_heal()` is **not** here, see SquadSpecials below) | Content Data (stat_block, cost) | `RandomNumberGenerator` (injected) — **implemented**, LOW risk |
| SquadSpecials | The squad's 4 named specials (stun, heal-party, heal-single, direct-damage) and their `calculate_heal()` (F4) | `make_speak_to_the_manager()`, `make_family_meal()`, `make_appetizer()`, `make_home_run()`, `calculate_heal(power, healer)` | Turn Battle System (the `Move`/`SpecialEffect` vocabulary it builds on) | **implemented** — `src/battle/squad/specials.gd`. No owning system in `systems-index.md` yet; closest fit is Turn Battle System or a future Quirk State System (see Open Questions) |
| ChapterFlow | Multi-fight sequencing: constructs `BattleCore` instances, listens to `battle_ended`, carries squad HP/MP between fights, drives chapter-won | `fight_started`, `fight_lost`, `chapter_won` signals | Turn Battle System, Faction Rule Modifiers | **implemented** — `src/chapters/chapter_flow.gd`. Overlaps Game State & Scene Flow's designed scope (see that row); resolve ownership in Game State's own ADR, not here |
| Squad Roster & Recruitment | Join/leave state, active party | join/leave events | Content Data (Character records) | Not yet implemented |
| Dialogue, Banter & Quests | Dialogue state, quest flags | overlay open/close | Game State, Input, Content Data | `RichTextLabel` — 4.7 image-sizing change if inline icons used |
| Save/Load & Settings | Serialized state, binding overrides | `save()`/`load()` | Game State (safe moments), Content Data (IDs only) | `FileAccess`; format is an open ADR |
| Turn Battle System | Battle state machine, outcome log | `submit_action(move, target) -> BattleOutcome`, `start_battle(reset_squad := true)`, `retry_battle()`, `BattleCore.new(squad, enemies, rng, faction_rule)`, `get_living_squad()`/`get_living_enemies()`/`get_active_combatant()`, 4 signals | Stats & Damage, Faction Rule Modifiers | **implemented**, LOW risk |
| Quirk State System | Active states per combatant | apply/consume, duration | Turn Battle, Stats & Damage | Not yet implemented — relationship to today's `SpecialEffect` enum (owned by `SquadSpecials`/Turn Battle System) is `INTENT UNKNOWN` |
| Combo System & Codex | Combo matching, Codex unlocks | combo-fired event | Quirk State, Turn Battle | Not yet implemented |
| Faction Rule Modifiers | Per-faction rule/AI/presentation | 9-method hook contract on `FactionRule` | Turn Battle (consulted by), Stats & Damage | **implemented** (Bureaucratia, MegaCorp), LOW risk. Retroactive ADR recommended before ADR-0001's migration touches it — see Required ADRs |
| Enemy AI | Collapses into Faction Rule Modifiers at MVP scope | — | — | — |
| Overworld Exploration & Encounters | Map state, player position, encounters, camp spots | Encounter descriptors | Game State, Input, Content Data, Sprite/Camera, Dialogue | Not yet implemented — **blocked on 3 ADRs** (Game State, Input, Sprite & Camera), movement mechanism is its own open ADR |
| Camp & Party Management | Active squad at camp | swap-party hook | Squad Roster, Game State | Not yet implemented |
| Leveling & Loyalty | XP/level, loyalty, unlocks | — | Stats & Damage, Squad Roster, Dialogue | Not yet implemented (Vertical Slice) |
| Faction Reputation & Endings | Reputation counters, ending choice | — | Squad Roster, Dialogue | Not yet implemented (MVP-lite → Alpha) |
| Items, Equipment & Shops | Inventory, shop stock | — | Content Data, Stats & Damage | Not yet implemented (Vertical Slice) |
| UI Framework | Battle UI, menus, HUD, dialogue UI | — (leaf, mostly consumes) | nearly everything | `Control`, `Tween` — **partially implemented** (battle HUD); `AccessKit` — 4.5+, HIGH risk, untouched; dual-focus (4.6) untested — see Open Questions |
| Audio Manager | Music/SFX bus state | cue reactions | Game State, Turn Battle, Combo, Faction Rules, Overworld | `AudioStreamPlayer`, bus API — 4.7 `area_mask` default flip, MEDIUM risk |
| Onboarding & Tutorial | Tutorial-step gating | — | Turn Battle, Quirk State, Combo, UI Framework | none beyond UI Framework's own |

## Data Flow

1. **Input path** (event-driven, not per-frame simulation — a turn-based menu
   game): device event → Input System (resolves an action) → Game State &
   Scene Flow (routes to current mode/overlay, applies input lock) → the
   owning system acts → signals fire → UI Framework redraws.
2. **Signal path**: Turn Battle System's 4 signals and Game State & Scene
   Flow's 6 named signals (see Module Ownership) are the established model —
   Presentation listens, never calls back into mutating methods (verified of
   `BattleHud` this session). All synchronous, same-thread — no threading
   anywhere in this project.
3. **Save/load path**: Save/Load & Settings (not built) owns serialization;
   stores IDs plus runtime state only — the Content Data Definitions catalog
   itself is never serialized (Rule 7, read-only). Game State & Scene Flow
   defines the safe-save window.
4. **Initialization order**: Boot → `ContentCatalog` autoload's `_ready()`
   (guaranteed before the main scene, ADR-0001) → `load_all()` → Ready/Failed
   → Game State & Scene Flow leaves Boot for Title only once Ready.

## API Boundaries

- **`ContentCatalog`** (Foundation, ADR-0001): `get_record(type, id)`,
  `has_record(type, id)`, `all_records(type)` (ID-sorted), `resolve_alias(id)`,
  `state`. Guarantee: `Ready` is terminal and immutable; a rejected lookup
  never returns partial data. Invariant: callers never mutate a returned
  `Resource`.
- **`BattleCore`** (Feature, implemented — `src/battle/battle_core.gd`):
  `BattleCore.new(squad, enemies, rng, faction_rule)`,
  `submit_action(move, target) -> BattleOutcome`,
  `start_battle(reset_squad := true)`, `retry_battle()`,
  `get_living_squad()`/`get_living_enemies()`/`get_active_combatant()`, 4
  signals (`turn_started`, `action_resolved`, `round_advanced`,
  `battle_ended`). Guarantee: a rejected action changes no state, returns
  `null`.
- **`FactionRule`** (Feature, implemented — `src/battle/factions/faction_rule.gd`):
  9-method hook contract, neutral defaults on the base class. Guarantee:
  `BattleCore` never branches on which subclass is active.
- **`SquadSpecials`** (Feature, implemented — `src/battle/squad/specials.gd`):
  4 named-special factories plus `calculate_heal(power, healer)` (F4).
  Guarantee: every special resolves through Turn Battle System's existing
  `Move`/`SpecialEffect` dispatch — no parallel resolution path.
- **`Game State & Scene Flow`** (Foundation, fully specified, not built):
  `request_transition(target_mode, payload)`, `open_overlay(kind, payload)`/
  `close_overlay()`; 6 named signals (Module Ownership). Guarantee: exactly
  one transition at a time, rejected (never queued) if one is already
  running; input locked for its duration. `Node`/`SceneTree` — LOW risk
  (fundamental, pre-cutoff), but the exact scene-swap mechanism, and its
  relationship to the already-shipped `ChapterFlow`, are undecided (Required
  ADRs, below).
- **`Input System`** (Foundation, not yet an ADR — proposed surface only,
  named so the ADR starts from a contract rather than inventing one from
  scratch): see Module Ownership's Exposes cell for the proposed method and
  signal names, sourced directly from `input-system.md` Rules 1 and 9. This
  system's own ADR is where these names are confirmed or changed — flagging
  here only that a near-term, "must have before coding starts" system should
  not reach implementation with an unnamed API.

## ADR Audit

| ADR | Engine Compat | Version | GDD Linkage | Conflicts | Valid |
|---|---|---|---|---|---|
| ADR-0001: Content Data Storage Format | ✅ | ✅ Godot 4.7.2 | ✅ | None | ✅ |

### Technical Requirements Baseline — full list (resolves TD item 1)

17 provisional requirements across 6 GDDs (TR registry is still empty — every
ID below is provisional, assigned starting at 001 per system per
`docs/architecture/tr-registry.yaml`'s own numbering rule):

| Req ID | GDD | Requirement | ADR Coverage |
|---|---|---|---|
| TR-content-001 | content-data-definitions.md | 7 record types + reserved types, permanent snake_case IDs, alias chain=error | ADR-0001 ✅ |
| TR-content-002 | content-data-definitions.md | Unloaded→Loading→Validating→Ready\|Failed state machine; Ready is terminal | ADR-0001 ✅ |
| TR-content-003 | content-data-definitions.md | Validation reports every problem per load; standalone headless check | ADR-0001 ✅ |
| TR-content-004 | content-data-definitions.md | `get_record`/`has_record`/`all_records`/`resolve_alias` lookup API | ADR-0001 ✅ |
| TR-gamestate-001 | game-state-scene-flow.md | Single-mode + stacked-overlay state machine | ❌ No ADR |
| TR-gamestate-002 | game-state-scene-flow.md | One transition at a time; input locked for its duration | ❌ No ADR |
| TR-gamestate-003 | game-state-scene-flow.md | Overworld freeze/restore around Battle; Encounter descriptor contract | ❌ No ADR |
| TR-gamestate-004 | game-state-scene-flow.md | Retry (no scene load) vs Retreat (to last camp) | ❌ No ADR (and overlaps `ChapterFlow`'s shipped retry/sequencing — see Module Ownership) |
| TR-input-001 | input-system.md | 8-action set; data-driven default bindings | ❌ No ADR |
| TR-input-002 | input-system.md | Radial deadzone + menu-repeat timing formulas | ❌ No ADR |
| TR-input-003 | input-system.md | Device identity via Godot 4.7 `DEVICE_ID_*` constants | ❌ No ADR — HIGH RISK, post-cutoff, not yet empirically verified |
| TR-input-004 | input-system.md | `device_lost`/`device_restored`/`focus_lost`/`focus_gained` broadcasts | ❌ No ADR |
| TR-stats-001 | stats-damage-resolution.md | F3–F7 damage/heal pipeline | Implemented, no ADR (retroactive candidate) |
| TR-stats-002 | stats-damage-resolution.md | RNG always injected, never global | Implemented, no ADR (retroactive candidate) |
| TR-turnbattle-001 | turn-battle-system.md | Turn state machine, Attack/Defend/Special dispatch | Implemented, no ADR (retroactive candidate) |
| TR-turnbattle-002 | turn-battle-system.md | MP gating + targeting + FactionRule hook consultation | Implemented, no ADR (retroactive candidate) |
| TR-factionrules-001 | faction-rule-modifiers.md | 9-method FactionRule hook contract | Implemented, no ADR (retroactive candidate — **should have one before ADR-0001's migration touches it**, see Required ADRs) |

**Count: 4 covered (TR-content-001–004), 13 gaps** (4 undecided-and-unbuilt in
Game State, 4 undecided-and-unbuilt in Input, 5 implemented-without-a-
retroactive-ADR in Stats & Damage/Turn Battle/Faction Rules).

## Required ADRs

**Must have before coding starts (Foundation & Core):**
- Game State & Scene Flow — scene management/mode-transition implementation
  strategy; must also resolve its overlap with the already-shipped
  `ChapterFlow` (TR-gamestate-001 to 004)
- Input System — concrete method/signal names for the proposed surface above
  (TR-input-001 to 004)
- Sprite & Camera Presentation — the lit-diorama rendering approach and fixed
  battle-camera implementation (promoted here from "should have," since
  Overworld depends on it directly — resolves TD item 2 / LP item 1)

**Explicit build order** (resolves TD item 2 / LP item 1): Overworld
Exploration & Encounters cannot start until **all three** of the above are
Accepted — its own Module Ownership row consumes all three directly. The
"system requested next" phrasing elsewhere in this document is a *design*
priority, not permission to start that code before its prerequisites land.

**Should have before the relevant system is built:**
- Overworld Exploration & Encounters — movement/map representation (grid,
  `TileMapLayer`, or free-roam — see Open Questions for the free-roam/Jolt
  interaction)
- Save/Load & Settings — serialization format
- **Retroactive ADR for Faction Rule Modifiers** (moved up from "can defer" —
  resolves TD item 4): ADR-0001's migration gives this system's code
  ownership of resolving `rule_id`, making its hook contract an interface
  ADR-0001 now depends on. Write this retroactive ADR at the same time as
  that migration, and do not start the migration's battle-factory changes
  until ADR-0001's own Migration Plan Step 0 (characterization tests under
  `tests/unit/battle/`, which do not exist yet) is in place.

**Can defer to implementation:**
- Retroactive ADRs for Stats & Damage Resolution / Turn Battle System
  (shipped, working, no interface changes pending — paperwork catch-up only,
  via `/architecture-decision retrofit`)
- Audio Manager bus architecture (Vertical Slice priority, not built)
- Quirk State / Combo System architecture (blocked on the open design
  question already carried in `turn-battle-system.md`, not an architecture gap)

## Performance Budget

`project.yaml` sets 60 fps / 16.6 ms frame budget. No per-system allocation
exists yet — low urgency today (this is an event-driven, turn-based game with
no continuous simulation loop), but the lit-diorama rendering direction
(`AreaLight3D`, Compositor — both HIGH risk, unverified) is where real frame
cost will land once Sprite & Camera Presentation is built. Its own ADR should
include a frame-time acceptance criterion rather than deferring the question
further.

## Architecture Principles

1. **Gameplay values are data, never hardcoded.** The coding standard this
   project already states, now backed by ADR-0001's concrete mechanism.
2. **The joke is the mechanic** (Pillar 1). Satire is expressed through
   combat rules (Faction Rule Modifiers), not just text — already proven by
   Bureaucratia's permit ban and MegaCorp's billing.
3. **Readable in One Turn** (Pillar 4). Every system's state is legible
   without a tutorial: Turn Battle System's full outcome log plus signals,
   Game State & Scene Flow's single predictable transition door, are both
   expressions of this.
4. **One door in, per system** — with one explicit, bounded exception.
   `request_transition()`/`open_overlay()`, `ContentCatalog`'s single lookup
   API, `FactionRule`'s single hook contract — no system reaches around
   another's owned state. **Exception**: `ContentCatalog` is a Godot autoload
   singleton (ADR-0001), justified only because it is read-only after
   `Ready`. This is not precedent for a *mutable* singleton anywhere else —
   Game State & Scene Flow, the next system likely to face this same
   DI-vs-singleton question, must not cite this exception without the same
   read-only justification.
5. **RNG is always injected, never global** (Stats & Damage F6). Already
   enforced throughout the shipped battle code; carries forward to every new
   system.

## Open Questions

- **Scene-transition implementation mechanism** (Game State & Scene Flow's own
  Open Question #4): autoload state machine, scene-tree swapping, or
  sub-viewports. Blocks that system's own ADR, which also must resolve its
  overlap with `ChapterFlow`.
- **Overworld movement/map representation**: undecided, blocks Overworld
  Exploration & Encounters. **Choosing free-roam reopens the Physics/Jolt HIGH
  risk rating** (Jolt is the default 3D physics engine since 4.6) — a
  grid/`TileMapLayer` choice avoids it entirely.
- **Quirk State / Combo System's relationship to today's `SpecialEffect`
  enum** (owned by `SquadSpecials`): `INTENT UNKNOWN`, carried from
  `turn-battle-system.md`'s own Open Questions.
- **UI focus handling under 4.6+ dual-focus, and AccessKit (4.5+)**: neither
  is tracked by an ADR or a Required ADR entry yet, despite UI being rated
  HIGH risk and the battle HUD already being built on `Control`. Coupled to
  the Input System ADR (which owns the device/focus signals) — resolve there
  or add a dedicated one before UI Framework work continues past the battle
  HUD.
- **Save/Load serialization format**: undecided.
- **Does randomness repeat on Retry?** (Game State & Scene Flow's own Open
  Question #2) — Turn Battle System's `retry_battle()` exists; whether its
  RNG state resets or continues is not yet decided.
